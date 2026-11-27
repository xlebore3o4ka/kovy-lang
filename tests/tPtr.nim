import std/[os, sequtils, strutils, unittest]
import parser/[lexer, parser]
import errors
import ast
import types
import visitors/[sema, nimgen]

const localePath =
  currentSourcePath().parentDir() / ".." / "src" / "error_locales" / "en.json"

type
  Analysis = object
    errors: seq[Error]
    generated: string

proc analyze(source: string): Analysis =
  let ctx = newErrorContext(localePath)
  let files = FileTracker()
  let lexer = newLexer(source, ctx, files.newFile("<test>", source))
  let parser = newParser(lexer, ctx)
  let tree = parser.parse()

  let sema = newSema(ctx, files)
  discard sema.visit(tree)
  sema.finalize()

  result.errors = ctx.errors
  if result.errors.len == 0:
    result.generated = newNimgen(ctx).emit(tree)
    result.errors = ctx.errors

proc kinds(analysis: Analysis): seq[ErrorKind] =
  analysis.errors.mapIt(it.kind)

proc parseTypeString(typeSource: string): Type =
  let source = typeSource & " value"
  let ctx = newErrorContext(localePath)
  let files = FileTracker()
  let lexer = newLexer(source, ctx, files.newFile("<test>", source))
  let parser = newParser(lexer, ctx)
  let tree = parser.parse()
  check ctx.errors.len == 0
  check tree.kind == nkBlock
  check Block(tree).stmts.len == 1
  check Block(tree).stmts[0].kind == nkDecl
  result = Decl(Block(tree).stmts[0]).typ

suite "pointer types":
  test "pointer syntax":
    let typ = parseTypeString("int*")
    check typ.kind == typePtr
    check typ.args.len == 1
    check typ.args[0].toStr == "int"
    check typ.toStr == "int*"

  test "pointer suffixes repeat":
    let typ = parseTypeString("int**")
    check typ.kind == typePtr
    check typ.args[0].kind == typePtr
    check typ.args[0].args[0].toStr == "int"
    check typ.toStr == "int**"

  test "pointer to function type":
    let typ = parseTypeString("int(bool)*")
    check typ.kind == typePtr
    check typ.args[0].kind == typeFunc
    check typ.args[0].funcReturnType[].toStr == "int"
    check typ.args[0].funcArgTypes[0].toStr == "bool"
    check typ.toStr == "int(bool)*"

  test "sameType compares pointers":
    check sameType(newPtrType(newIntType()), newPtrType(newIntType()))
    check not sameType(newPtrType(newIntType()), newPtrType(newBoolType()))
    check not sameType(newPtrType(newIntType()), newIntType())

  test "hash is stable for pointers":
    check hash(newPtrType(newIntType())) == hash(newPtrType(newIntType()))

suite "alloc":
  test "allocates a pointer to the element type":
    let a = analyze("""
int* p = alloc 4 of int
""")
    check a.errors.len == 0
    check "cast[ptr int]" in a.generated
    check "kovyRuntime.kovyAlloca((4) * sizeof(int))" in a.generated

  test "count expression keeps its precedence":
    let a = analyze("""
int n = 2
int* p = alloc n + 1 of int
""")
    check a.errors.len == 0
    check "kovyAlloca((n + 1) * sizeof(int))" in a.generated

  test "count multiplication keeps its precedence":
    let a = analyze("""
int n = 2
int* p = alloc n * 2 of int
int* q = alloc (n + 1) * 2 of int
""")
    check a.errors.len == 0
    check "kovyAlloca((n * 2) * sizeof(int))" in a.generated
    check "kovyAlloca(((n + 1) * 2) * sizeof(int))" in a.generated

  test "pointer element type":
    let a = analyze("""
int** pp = alloc 2 of int*
""")
    check a.errors.len == 0
    check "cast[ptr ptr int]" in a.generated
    check "sizeof(ptr int)" in a.generated

  test "non-number count is rejected":
    let a = analyze("""
int* p = alloc true of int
""")
    check kinds(a) == @[errAllocCount]

  test "alloc of void is rejected":
    let a = analyze("""
void* p = alloc 4 of void
""")
    check kinds(a) == @[errAllocVoid]

  test "alloc inside a loop is rejected":
    let a = analyze("""
int mut i = 0
while i < 3:
  int* p = alloc 4 of int
  i = i + 1
""")
    check kinds(a) == @[errAllocInLoop]

  test "alloc inside a branch in a loop is rejected":
    let a = analyze("""
int mut i = 0
while i < 3:
  if i == 0:
    int* p = alloc 4 of int
  i = i + 1
""")
    check kinds(a) == @[errAllocInLoop]

  test "alloc outside a loop is allowed":
    let a = analyze("""
int* p = alloc 4 of int
int mut i = 0
while i < 3:
  i = i + 1
""")
    check a.errors.len == 0

  test "alloc inside a function declared in a loop is allowed":
    let a = analyze("""
int mut i = 0
while i < 3:
  void inner():
    int* p = alloc 4 of int
  inner()
  i = i + 1
""")
    check a.errors.len == 0

suite "array literals":
  test "allocates and fills an int array":
    let a = analyze("""
int* p = [1, 2, 3]
""")
    check a.errors.len == 0
    check "kovyRuntime.kovyArrayLit(3, int, 1, 2, 3)" in a.generated

  test "uses the explicit element type":
    let a = analyze("""
int* p = [1, 2] of int
""")
    check a.errors.len == 0
    check "kovyRuntime.kovyArrayLit(2, int, 1, 2)" in a.generated

  test "infers bool elements":
    let a = analyze("""
bool* p = [true, false]
""")
    check a.errors.len == 0
    check "kovyRuntime.kovyArrayLit(2, bool, true, false)" in a.generated

  test "empty array literal":
    let a = analyze("""
int* p = [] of int
""")
    check a.errors.len == 0
    check "kovyRuntime.kovyArrayLit(0, int)" in a.generated

  test "array of function values":
    let a = analyze("""
void hello():
  int mut x = 1
void()* p = [hello] of void()
""")
    check a.errors.len == 0
    check "kovyRuntime.kovyArrayLit(1, proc (): void, helloza1)" in a.generated
    check "ptr (proc (): void)" in a.generated

  test "mutable pointer allows writing through an element":
    let a = analyze("""
int* mut p = [1, 2]
#p = 3
""")
    check a.errors.len == 0
    check "var p: ptr int = kovyRuntime.kovyArrayLit(2, int, 1, 2)" in a.generated
    check "(p)[] = 3" in a.generated

  test "nested array literals":
    let a = analyze("""
int** p = [[1, 2], [3, 4]] of int*
""")
    check a.errors.len == 0
    check "kovyRuntime.kovyArrayLit(2, ptr int, " in a.generated
    check "kovyRuntime.kovyArrayLit(2, int, 1, 2)" in a.generated
    check "kovyRuntime.kovyArrayLit(2, int, 3, 4)" in a.generated

suite "dereference":
  test "mutable pointer variable":
    let a = analyze("""
int* mut p = alloc 1 of int
#p = 5
int mut x = #p
""")
    check a.errors.len == 0
    check "(p)[] = 5" in a.generated
    check "var x: int = (p)[]" in a.generated

  test "pointer arithmetic operand":
    let a = analyze("""
int* mut p = alloc 2 of int
#(p + 1) = 2
""")
    check a.errors.len == 0
    check "(p + 1)[] = 2" in a.generated

  test "double dereference":
    let a = analyze("""
int* mut q = alloc 1 of int
int** mut pp = alloc 1 of int*
#pp = q
##pp = 7
""")
    check a.errors.len == 0
    check "((pp)[])[] = 7" in a.generated

  test "dereferencing a non-pointer is rejected":
    let a = analyze("""
int mut x = 1
int y = #x
""")
    check kinds(a) == @[errDerefNonPointer]

suite "write permission":
  test "immutable pointer variable cannot write":
    let a = analyze("""
int* p = alloc 1 of int
#p = 10
""")
    check kinds(a) == @[errImmutableAssignment]

  test "immutable pointer variable can read":
    let a = analyze("""
int* p = alloc 1 of int
int x = #p
""")
    check a.errors.len == 0
    check "let x: int = (p)[]" in a.generated

  test "pointer arithmetic keeps write permission from a mutable pointer":
    let a = analyze("""
int* mut p = alloc 2 of int
#(p + 1) = 2
#(1 + p) = 3
#(p - 1) = 4
""")
    check a.errors.len == 0
    check "(p + 1)[] = 2" in a.generated
    check "(1 + p)[] = 3" in a.generated
    check "(p - 1)[] = 4" in a.generated

  test "pointer arithmetic from an immutable pointer cannot write":
    let a = analyze("""
int* p = alloc 2 of int
#(p + 1) = 2
""")
    check kinds(a) == @[errImmutableAssignment]

  test "pointer difference is not writable":
    let a = analyze("""
int f(int* mut a, int* mut b):
  #(a - b) = 1
  return 0
""")
    check kinds(a) == @[errDerefNonPointer]

  test "addr becomes writable only through a mutable symbol":
    let a = analyze("""
int mut x = 1
int* mut p = addr x
#p = 5
""")
    check a.errors.len == 0
    check "(p)[] = 5" in a.generated

  test "immutable symbol holding an address cannot write":
    let a = analyze("""
int mut x = 1
int* p = addr x
#p = 5
""")
    check kinds(a) == @[errImmutableAssignment]

  test "direct addr dereference cannot write":
    let a = analyze("""
int mut x = 1
#(addr x) = 5
""")
    check kinds(a) == @[errImmutableAssignment]

  test "direct alloc dereference cannot write":
    let a = analyze("""
#(alloc 1 of int) = 5
""")
    check kinds(a) == @[errImmutableAssignment]

  test "mutable pointer parameter can write":
    let a = analyze("""
int f(int* mut p):
  #p = 5
  return 0
""")
    check a.errors.len == 0
    check "(p)[] = 5" in a.generated

  test "immutable pointer parameter cannot write":
    let a = analyze("""
int f(int* p):
  #p = 5
  return 0
""")
    check kinds(a) == @[errImmutableAssignment]

  test "mutable pointer return grants write access":
    let a = analyze("""
int* mut pick(int* mut p):
  return p

int f(int* mut p):
  #pick(p) = 5
  return 0
""")
    check a.errors.len == 0
    check "(pickza1(p))[] = 5" in a.generated

  test "immutable pointer return does not grant write access":
    let a = analyze("""
int* pick(int* p):
  return p

int f(int* p):
  #pick(p) = 5
  return 0
""")
    check kinds(a) == @[errImmutableAssignment]

  test "addr of a dereference requires a mutable pointer":
    let a = analyze("""
int* p = alloc 1 of int
int* q = addr #p
""")
    check kinds(a) == @[errAddrFromImmutable]

suite "addr":
  test "mutable symbol":
    let a = analyze("""
int mut x = 1
int* p = addr x
""")
    check a.errors.len == 0
    check "addr (x)" in a.generated

  test "dereference":
    let a = analyze("""
int* mut p = alloc 1 of int
int* q = addr #p
""")
    check a.errors.len == 0
    check "addr ((p)[])" in a.generated

  test "mutable function call":
    let a = analyze("""
int mut g(int mut x):
  return x

int* f(int mut x):
  return addr g(x)
""")
    check a.errors.len == 0
    check "addr (gza1(x))" in a.generated

  test "mutable pointer variable yields pointer to pointer":
    let a = analyze("""
int* mut p = alloc 1 of int
int** pp = addr p
""")
    check a.errors.len == 0
    check "let pp: ptr ptr int = addr (p)" in a.generated

  test "immutable expression is rejected":
    let a = analyze("""
int x = 1
int* p = addr x
""")
    check kinds(a) == @[errAddrFromImmutable]

suite "pointer arithmetic":
  test "valid operations":
    let a = analyze("""
int* advance(int* p, int n):
  return p + n

int* advanceLeft(int* p, int n):
  return n + p

int* retreat(int* p, int n):
  return p - n

int distance(int* a, int* b):
  return a - b
""")
    check a.errors.len == 0
    check "return p + n;" in a.generated
    check "return n + p;" in a.generated
    check "return p - n;" in a.generated
    check "return a - b;" in a.generated

  test "int - ptr is rejected":
    let a = analyze("""
int bad(int* p):
  return 1 - p
""")
    check kinds(a) == @[errBinaryMismatch]

  test "ptr + ptr is rejected":
    let a = analyze("""
int* bad(int* p, int* q):
  return p + q
""")
    check kinds(a) == @[errBinaryMismatch]

  test "ptr - ptr with different pointee types is rejected":
    let a = analyze("""
int bad(int* p, bool* q):
  return p - q
""")
    check kinds(a) == @[errBinaryMismatch]

  test "pointer comparison is rejected":
    let a = analyze("""
bool bad(int* a, int* b):
  return a < b
""")
    check kinds(a) == @[errBinaryMismatch]

suite "function pointers":
  # As in C, prefix `#` binds looser than a postfix call: `#p()` means
  # `#(p())`. To call through a function pointer, use `(#p)()`.
  test "call through a function pointer":
    let a = analyze("""
void hello():
  int mut x = 1

void()* mut dispatch = alloc 1 of void()
#dispatch = hello
(#dispatch)()
""")
    check a.errors.len == 0
    check "cast[ptr (proc (): void)]" in a.generated
    check "kovyAllocaZeroed((1) * sizeof(proc (): void))" in a.generated
    check "(dispatch)[] = helloza1" in a.generated
    check "(dispatch)[]()" in a.generated

  test "call through pointer arithmetic":
    let a = analyze("""
void hello():
  int mut x = 1

void()* mut dispatch = alloc 2 of void()
#(dispatch + 1) = hello
(#(dispatch + 1))()
""")
    check a.errors.len == 0
    check "(dispatch + 1)[] = helloza1" in a.generated
    check "(dispatch + 1)[]()" in a.generated

  test "unparenthesized call is parsed inside the dereference":
    let a = analyze("""
void()* p
int i = 0
#(p + i)()
""")
    check kinds(a) == @[errNotCallable]

suite "runtime names":
  test "user symbols colliding with syskovy names are escaped":
    let a = analyze("""
int kovyruntime = 1
int kovyalloca = 2
int kovyarraylit = 3
int syskovy = 4
""")
    check a.errors.len == 0
    check " except kovyAlloca, kovyAllocaZeroed, kovyArrayLit" in a.generated
    check "zkovyruntime" in a.generated
    check "zkovyalloca" in a.generated
    check "zkovyarraylit" in a.generated
    check "zsyskovy" in a.generated