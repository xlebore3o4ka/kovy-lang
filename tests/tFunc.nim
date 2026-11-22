import std/[os, sequtils, strutils, unittest]
import parser/[lexer, parser]
import errors
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
    result.generated = newNimgen().emit(tree)

proc kinds(analysis: Analysis): seq[ErrorKind] =
  analysis.errors.mapIt(it.kind)

suite "functions":
  test "grouped parameters become separate arguments":
    let a = analyze("""
int add(int a, b):
  return a + b

int c = add(1, 2)
""")
    check a.errors.len == 0
    check "(a: int, b: int)" in a.generated
    check ", 2)" in a.generated

  test "parameter groups can change type":
    let a = analyze("""
int f(int a, bool b):
  return a
""")
    check a.errors.len == 0
    check "(a: int, b: bool)" in a.generated

  test "grouped mutable parameters share mutability":
    let a = analyze("""
int f(int mut a, b):
  a = b
  return a
""")
    check a.errors.len == 0
    check "(a: var int, b: var int)" in a.generated

  test "void calls are not discarded":
    let a = analyze("""
void hello():
  int x = 1

void main():
  hello()
""")
    check a.errors.len == 0
    check "hello" in a.generated
    check "discard hello" notin a.generated

  test "overloaded void calls are not discarded":
    let a = analyze("""
void show(int x):
  int y = x

void show(bool x):
  int y = 1

void main():
  show(1)
  show(true)
""")
    check a.errors.len == 0
    check "discard show" notin a.generated

  test "forward declaration and definition match":
    let a = analyze("""
int add(int a, b)
int add(int a, b):
  return a + b

int f(int a, int b):
  return add(a, b)
""")
    check a.errors.len == 0

  test "unresolved forward declaration is reported":
    let a = analyze("""
int add(int a, b)
""")
    check errUnresolvedForward in a.kinds

  test "recursive calls are resolved":
    let a = analyze("""
int fact(int n):
  if n <= 1:
    return 1
  else:
    return n * fact(n - 1)
""")
    check a.errors.len == 0
    check "fact" in a.generated

  test "default parameter values are forbidden":
    let a = analyze("""
int f(int a = 1):
  return a
""")
    check errDefaultForbidden in a.kinds

  test "all paths returning through if/else are accepted":
    let a = analyze("""
int f(int n):
  if n > 0:
    return 1
  else:
    return 2
""")
    check a.errors.len == 0

  test "missing return path is reported":
    let a = analyze("""
int f(int n):
  if n > 0:
    return 1
""")
    check errNotAllPathsReturn in a.kinds

  test "while true does not require a return after the loop":
    let a = analyze("""
int f(int n):
  while true:
    return 1
""")
    check errNotAllPathsReturn notin a.kinds

  test "while true with break still requires a return":
    let a = analyze("""
int f(int n):
  while true:
    break
""")
    check errNotAllPathsReturn in a.kinds

  test "break in a nested loop does not exit the outer loop":
    let a = analyze("""
int f(int n):
  while true:
    while true:
      break
    return 1
""")
    check errNotAllPathsReturn notin a.kinds

  test "code after an exhaustive if/else is unreachable":
    let a = analyze("""
int f(int n):
  if n > 0:
    return 1
  else:
    return 2
  return 3
""")
    check errUnreachableCode in a.kinds

  test "empty function body is rejected":
    let a = analyze("""
void f():
int g():
  int x = 1
""")
    check errEmptyFunctionBody in a.kinds

  test "nested functions cannot be overloaded":
    let a = analyze("""
int outer(int n):
  int f(int a):
    return a
  int f(int a, int b):
    return a + b
  return f(n)
""")
    check errFuncRedefinition in a.kinds

  test "function values can be declared and called":
    let a = analyze("""
int add(int a, int b):
  return a + b
int(int, int) f = add
int x = f(1, 2)
""")
    check a.errors.len == 0
    check "proc (a0: int, a1: int): int" in a.generated
    check "= addza1" in a.generated
    check "f(1, 2)" in a.generated

  test "functions can be passed as arguments":
    let a = analyze("""
int add(int a, int b):
  return a + b
int apply(int(int, int) f, int a, int b):
  return f(a, b)
int x = apply(add, 1, 2)
""")
    check a.errors.len == 0
    check "f: proc (a0: int, a1: int): int" in a.generated
    check "applyza2(addza1, 1, 2)" in a.generated

  test "functions can be returned and called":
    let a = analyze("""
int add(int a, int b):
  return a + b
int(int, int) get():
  return add
int x = get()(1, 2)
""")
    check a.errors.len == 0
    check "getza2(): proc (a0: int, a1: int): int" in a.generated
    check "getza2()(1, 2)" in a.generated

  test "mutable parameters are preserved in function types":
    let a = analyze("""
int add(int mut a, int b):
  a = a + b
  return a
int apply(int(mut int, int) f):
  int mut x = 1
  return f(x, 2)
int y = apply(add)
""")
    check a.errors.len == 0
    check "proc (a0: var int, a1: int): int" in a.generated

  test "overloaded functions resolve by expected type":
    let a = analyze("""
int f(int a):
  return a
int f(bool a):
  return 1
int(int) g = f
int x = g(1)
""")
    check a.errors.len == 0
    check "= fza1" in a.generated

  test "overloaded functions resolve as call arguments":
    let a = analyze("""
int f(int a):
  return a
int f(bool a):
  return 1
int apply(int(int) fn, int x):
  return fn(x)
int y = apply(f, 1)
""")
    check a.errors.len == 0
    check "applyza3(fza1, 1)" in a.generated

  test "ambiguous function references are rejected":
    let a = analyze("""
int f(int a):
  return a
int f(bool a):
  return 1
int x = f
""")
    check errAmbiguousFunctionReference in a.kinds

  test "mutable function variables can be reassigned":
    let a = analyze("""
int add(int a, int b):
  return a + b
int sub(int a, int b):
  return a - b
int(int, int) mut f = add
f = sub
int x = f(3, 1)
""")
    check a.errors.len == 0
    check "var f: proc (a0: int, a1: int): int = addza1" in a.generated
    check "f = subza2" in a.generated

  test "void functions can be stored in function values":
    let a = analyze("""
void hello():
  int x = 1
void() f = hello
void main():
  f()
""")
    check a.errors.len == 0
    check "proc (): void" in a.generated
    check "f();" in a.generated
    check "discard f()" notin a.generated

  test "function values can return void functions":
    let a = analyze("""
void hello():
  int x = 1
void() get():
  return hello
void main():
  get()()
""")
    check a.errors.len == 0
    check "getza2(): proc (): void" in a.generated
    check "getza2()();" in a.generated