import std/[os, sequtils, strutils, unittest]
import parser/[lexer, parser]
import errors
import ast
import types
import visitors/sema

const localePath =
  currentSourcePath().parentDir() / ".." / "src" / "error_locales" / "en.json"

type
  Analysis = object
    errors: seq[Error]
    formatted: seq[string]
    tree: Stmt

proc analyze(source: string): Analysis =
  let ctx = newErrorContext(localePath)
  let files = FileTracker()
  let lexer = newLexer(source, ctx, files.newFile("<test>", source))
  let parser = newParser(lexer, ctx)
  let tree = parser.parse()

  let sema = newSema(ctx, files)
  discard sema.visit(tree)
  sema.finalize()

  result.tree = tree
  result.errors = ctx.errors
  for error in ctx.errors:
    result.formatted.add ctx.formatError(files, error)

proc kinds(analysis: Analysis): seq[ErrorKind] =
  analysis.errors.mapIt(it.kind)

proc suggestion(analysis: Analysis): string =
  for error in analysis.errors:
    if error.kind == errUnknownSymbol and error.placeholders.len > 1:
      return error.placeholders[1]

suite "array literals":
  test "infers the element type from the first element":
    let a = analyze("""
int* p = [1, 2, 3]
""")
    check a.errors.len == 0
    let decl = Decl(Block(a.tree).stmts[0])
    let lit = ArrayLit(decl.getDeclValue("p"))
    check not lit.hasElemType
    check lit.elemType.kind == typeInt

  test "infers bool elements":
    let a = analyze("""
bool* p = [true, false]
""")
    check a.errors.len == 0
    let decl = Decl(Block(a.tree).stmts[0])
    let lit = ArrayLit(decl.getDeclValue("p"))
    check lit.elemType.kind == typeBool

  test "uses the explicit element type":
    let a = analyze("""
int* p = [1, 2] of int
""")
    check a.errors.len == 0
    let decl = Decl(Block(a.tree).stmts[0])
    let lit = ArrayLit(decl.getDeclValue("p"))
    check lit.hasElemType
    check lit.elemType.kind == typeInt

  test "empty literal with an explicit element type":
    let a = analyze("""
int* p = [] of int
""")
    check a.errors.len == 0

  test "empty literal without an element type is rejected":
    let a = analyze("""
int* p = []
""")
    check kinds(a) == @[errArrayTypeRequired]

  test "mismatched elements are rejected":
    let a = analyze("""
int* p = [1, true]
""")
    check kinds(a) == @[errDoesNotFit]

  test "mismatched elements are rejected with an explicit type":
    let a = analyze("""
int* p = [1, true] of int
""")
    check kinds(a) == @[errDoesNotFit]

  test "void element type is rejected":
    let a = analyze("""
int* p = [] of void
""")
    check kinds(a) == @[errAllocVoid]

  test "void inferred from the first element is rejected":
    let a = analyze("""
void f():
  int x = 1
int* p = [f()]
""")
    check kinds(a) == @[errAllocVoid]

  test "mutable elements are read as values":
    let a = analyze("""
int mut x = 1
int* p = [x]
""")
    check a.errors.len == 0
    let decl = Decl(Block(a.tree).stmts[1])
    let lit = ArrayLit(decl.getDeclValue("p"))
    check lit.elemType.kind == typeInt

  test "literal inside a loop is rejected":
    let a = analyze("""
int mut i = 0
while i < 3:
  int* p = [1, 2]
  i = i + 1
""")
    check kinds(a) == @[errAllocInLoop]

  test "literal inside a function declared in a loop is allowed":
    let a = analyze("""
int mut i = 0
while i < 3:
  void inner():
    int* p = [1, 2]
  inner()
  i = i + 1
""")
    check a.errors.len == 0

suite "loop context":
  test "break inside a function declared in a loop is rejected":
    let a = analyze("""
int mut i = 0
while i < 3:
  void inner():
    break
  inner()
  i = i + 1
""")
    check a.errors.len == 1
    check a.errors[0].kind == errContextScope

suite "unknown symbol suggestions":
  test "suggests a close name from the current scope":
    let a = analyze("""
int counter = 1
int value = conter
""")
    check a.errors.len == 1
    check a.errors[0].kind == errUnknownSymbol
    check suggestion(a) == "counter"
    check "Perhaps you meant 'counter'?" in a.formatted[0]

  test "suggests names from outer scopes":
    let a = analyze("""
int counter = 1
int read():
  return conter
""")
    check suggestion(a) == "counter"

  test "prefers the closest visible name":
    let a = analyze("""
int value = 1
int f():
  int local = 2
  return valeu
""")
    check suggestion(a) == "value"

  test "suggests function names":
    let a = analyze("""
int add(int a):
  return a
int x = ad(1)
""")
    check suggestion(a) == "add"

  test "does not suggest a distant name":
    let a = analyze("""
int something = 1
int value = zzzzzz
""")
    check a.errors.len == 1
    check a.errors[0].kind == errUnknownSymbol
    check suggestion(a) == ""
    check "Perhaps" notin a.formatted[0]