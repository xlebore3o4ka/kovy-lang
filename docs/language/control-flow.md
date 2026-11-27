# Control flow

<!-- doc-id: KOVY-CONTROL-FLOW -->
<!-- status: current -->

<a id="KOVY-CONTROL-FLOW"></a>
Control flow covers branches, loops, `break`, `continue`, `return`, the
all-paths-return check, and unreachable-code detection. The implementation is
in `src/visitors/sema.nim`.

## Contexts

<a id="SEM-FLOW-CONTEXT"></a>
### Execution contexts

Sema maintains a stack of context scopes in addition to lexical scopes.

| Context | Pushed by | Effect |
|---|---|---|
| `branch` | each `if`/`elif`/`else` body | no direct effect on loop or return checks |
| `loop` | a `while` body | enables `break`/`continue`, forbids `alloc` and array literals |
| `func-arguments` | a function parameter list | no direct control-flow effect |
| `func` | a function body | enables `return`; supplies the expected return type; stops loop-context lookup |

`isLoopContext` scans from the innermost context outward. It returns `true` at
the first `loop`; it returns `false` at the first `func`. Therefore:

- `break`/`continue` inside a branch inside a loop are accepted;
- `break`/`continue` inside a nested function declared inside a loop are
  rejected;
- `alloc` and array literals inside a nested function declared inside a loop
  are allowed;
- `return` inside any nested function targets the innermost function.

`isFuncContext` scans the whole stack for any `func`; `return` outside every
function is `ERR-errContextScope`.

## Branches

<a id="SEM-FLOW-BRANCH"></a>
### `if` / `elif` / `else`

- The condition is checked with `fits(condition, bool)`.
- Every `elif` condition is checked independently.
- Each body is visited in its own branch scope.
- An absent `else` still gets an empty branch scope.
- All bodies are analyzed even when a condition is a literal `true` or
  `false`; there is no constant-condition pruning.

## Loops

<a id="SEM-FLOW-LOOP"></a>
### `while`

- The condition is checked with `fits(condition, bool)`.
- The body is visited in a loop scope.
- `break` and `continue` are accepted when a loop context is visible.
- `alloc` and array literals are rejected anywhere in a loop context, even in
  a conditional branch.
- There are no labels, `for` loops, `do` loops, or loop `else` clauses.

## Return

<a id="SEM-FLOW-RETURN"></a>
### Return checking

`visit(Return)` performs these steps:

1. If there is no function context, report `errContextScope` and stop.
2. If a value is present, visit it with the function's return type as the
   expected type.
3. If the function returns `void`, report `errVoidReturnValue`.
4. If the function returns a mutable type and the value is not mutable,
   report `errImmutableReturn`.
5. If the value does not fit the return type, report `errDoesNotFit`.
6. If both are mutable, apply the narrow dangling-mutable check below.
7. If no value is present and the function is non-void, report
   `errReturnValueExpected`.

A `void` function may use a bare `return`. A non-void function may not. The
parser decides whether `return` has a value by checking the next token:
`return` has no value only when the next token is `EOS`. At a dedent or EOF
without a preceding newline, the parser can instead try to parse an expression
and produce `errExpressionExpected`.

<a id="SEM-FLOW-RETURN-PATHS"></a>
### All-paths-return analysis

A non-void function whose body is not proven to return on every path reports
`ERR-errNotAllPathsReturn` at the function declaration. The proof is
deliberately syntactic:

```text
block returns        if any statement in the block returns
return                true
if/elif/else          true only with an else and true for every body
while true            true only for the literal boolean true and no break
                      that can be found syntactically in the body
anything else         false
```

Consequences:

- `if` without `else` is never exhaustive.
- Conditions are not evaluated; `if true:` is not treated as exhaustive.
- `while 1 == 1` is not recognized as non-fallthrough.
- `while true` with a `break` anywhere in its body requires a return after the
  loop.
- A `break` inside a nested loop does not count as a break of the outer loop.
- A `break` inside a nested function does not count.
- `continue` does not make a loop non-fallthrough.
- A block returns if any of its statements returns, because any statement
  before a guaranteed return either continues to it or exits the function.

<a id="SEM-FLOW-RETURN-DANGLING"></a>
### Mutable-return dangling check

The only lifetime-specific return check applies when the function returns a
mutable type and the returned expression is mutable:

1. Find the symbol that supplies mutability by walking through assignment
   expressions (left side), unary expressions (operand), calls (callee), and
   symbols.
2. Compare that symbol's lexical scope depth with the depth of the function's
   parameter scope.
3. If the symbol's scope is deeper, report `ERR-errReturnDanglingMutable`.

A mutable parameter has the same depth as the parameter scope and is allowed.
A mutable global has depth 0 and is allowed. A mutable local in the function
body or in a deeper branch is rejected.

Because a call is attributed to its callee symbol, returning the result of a
nested mutable-returning function can be rejected even when the nested
function returns one of its own parameters. This is a current implementation
quirk, not a general escape analysis.

The check does **not** cover ordinary pointer returns, `addr`, array literals,
assignment to globals, or passing pointers to other functions. See
[SEM-PTR-LIFETIME](pointers.md#SEM-PTR-LIFETIME).

## Unreachable code

<a id="SEM-FLOW-UNREACHABLE"></a>
### Unreachable code

While visiting any block, sema remembers the first statement for which
`controlAllReturnPaths` is true. Every later statement in that same block is
unreachable. One `ERR-errUnreachableCode` is reported at the founding
statement, with:

- `fromLine = founder.token.line + 1`;
- `toLine =` the line of the last statement in the block.

The later statements are still visited and checked. A second founding
statement does not produce a second unreachable error in the same block.

Only block statements are considered. A `return` that is the last statement
does not make anything unreachable. A `while true` without a visible `break`
makes all following statements in its block unreachable.

<a id="SEM-FLOW-EXITS-LOOP"></a>
### Break detection for `while true`

`exitsLoop` is a separate syntactic walk used only by `controlAllReturnPaths`:

- `break` is true;
- a block is true if any statement is true;
- a branch is true if any body is true; a missing `else` is false;
- nested `while` and nested function declarations are false, because their
  breaks belong to another context.

This is a "can any break be found" test, not a path-sensitive may-exit
analysis. A break in a branch that is statically unreachable still counts.

## Examples

<a id="EX-FLOW-IF-ELSE"></a>
<!-- expect-errors: OK -->
```kovy
int abs(int x):
  if x < 0:
    return -x
  else:
    return x
```

<a id="EX-FLOW-WHILE-TRUE"></a>
<!-- expect-errors: OK -->
```kovy
int firstPositive(int mut value):
  while true:
    value = value + 1
    if value > 0:
      return value
```

<a id="EX-FLOW-NOT-ALL"></a>
<!-- expect-errors: errNotAllPathsReturn -->
```kovy
int f(int x):
  if x > 0:
    return x
```

<a id="EX-FLOW-BREAK"></a>
<!-- expect-errors: errNotAllPathsReturn -->
```kovy
int f():
  while true:
    break
```

<a id="EX-FLOW-UNREACHABLE"></a>
<!-- expect-errors: errUnreachableCode -->
```kovy
int f():
  return 1
  int x = 2
```

<a id="EX-FLOW-DANGLING"></a>
<!-- expect-errors: errReturnDanglingMutable -->
```kovy
int mut f():
  int mut x = 1
  return x
```

## Diagnostics

- [ERR-errContextScope](../errors/errContextScope.md#ERR-errContextScope)
- [ERR-errVoidReturnValue](../errors/errVoidReturnValue.md#ERR-errVoidReturnValue)
- [ERR-errReturnValueExpected](../errors/errReturnValueExpected.md#ERR-errReturnValueExpected)
- [ERR-errImmutableReturn](../errors/errImmutableReturn.md#ERR-errImmutableReturn)
- [ERR-errReturnDanglingMutable](../errors/errReturnDanglingMutable.md#ERR-errReturnDanglingMutable)
- [ERR-errNotAllPathsReturn](../errors/errNotAllPathsReturn.md#ERR-errNotAllPathsReturn)
- [ERR-errUnreachableCode](../errors/errUnreachableCode.md#ERR-errUnreachableCode)

## Tests and implementation

- `tests/tFunc.nim`: all-paths return, `while true`, break, unreachable code
- `tests/tSema.nim`: break inside a function declared in a loop
- `src/visitors/sema.nim`: `visit(Branch)`, `visit(While)`, `visit(Return)`,
  `controlAllReturnPaths`, `exitsLoop`, `getMutabilitySource`