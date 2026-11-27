# Statements

<!-- doc-id: KOVY-STATEMENTS -->
<!-- status: current -->

<a id="KOVY-STATEMENTS"></a>
A program is a sequence of statements. Compound statements (`if`, `while`,
functions) introduce blocks; every other statement is simple and is separated
by `EOS` (newline or semicolon).

## Statement forms

<a id="SYN-STMT-EXPR"></a>
### Expression statement

```kovy
1 + 2
foo()
```

Any expression can stand as a statement. A void call is emitted directly.
A non-void value is emitted with Nim `discard`. Sema still checks the
expression; an invalid expression statement does not produce an extra
statement-specific error.

<a id="SYN-STMT-DECL"></a>
### Declaration statement

See [declarations](declarations.md#KOVY-DECLARATIONS).

<a id="SYN-STMT-IF"></a>
### `if` / `elif` / `else`

```ebnf
branch = "if" expression block
         { "elif" expression block }
         [ "else" block ] ;
```

```kovy
if x < 0:
  int sign = -1
elif x == 0:
  int sign = 0
else:
  int sign = 1
```

Rules:

- The condition is checked with `fits(condition, bool)`.
- `elif` conditions are checked independently.
- Each branch body has its own scope. Declarations do not leak out.
- `else` is optional. An `if` without `else` is not exhaustive for return
  analysis.
- Conditions are expressions, so assignment is syntactically allowed when its
  result fits `bool`.
- An inline body is one statement (`if true: int x = 1`).
- An indented body may be empty for `if`; an inline body cannot be empty.

<a id="SYN-STMT-WHILE"></a>
### `while`

```ebnf
whileStmt = "while" expression block ;
```

```kovy
int mut i = 0
while i < 3:
  i = i + 1
```

The condition must fit `bool`. The body has its own scope and a loop context.
`while true` is special for return analysis only when the body cannot
`break` out of it; see [control flow](control-flow.md#SEM-FLOW-RETURN-PATHS).

<a id="SYN-STMT-BREAK"></a>
### `break` and `continue`

```kovy
while true:
  break
```

`break` and `continue` take no operands. They are accepted only inside a loop
context. The loop context search stops at a function boundary: a nested
function declared inside a loop is not inside that loop for `break`,
`continue`, or `alloc` purposes.

`break` exits the innermost generated Nim loop. `continue` starts its next
iteration. There are no labels.

<a id="SYN-STMT-RETURN"></a>
### `return`

```ebnf
returnStmt = "return" [ expression ] ;
```

- `return` without a value is accepted only when the next token is `EOS`.
  At a dedent or EOF, the parser attempts to parse an expression and may emit
  `errExpressionExpected`; a trailing newline normally supplies the `EOS`.
- `return` is accepted only inside a function context.
- In a `void` function, returning a value is `errVoidReturnValue`.
- In a non-void function, a bare `return` is `errReturnValueExpected`.
- The returned value must fit the declared return type.
- A mutable-returning function requires a mutable value and applies the
  narrow `errReturnDanglingMutable` check.
- A non-void function must have all control paths returning; see
  [control flow](control-flow.md#SEM-FLOW-RETURN-PATHS).

```kovy
int f(int x):
  if x > 0:
    return x
  else:
    return -x
```

<a id="SYN-STMT-FUNC"></a>
### Function declaration statement

Function declarations are statements because they may occur globally or
inside another function body. See
[functions](functions.md#SYN-FUNC-DECL) and
[overloads](overloads.md#KOVY-OVERLOADS).

## Inline versus indented blocks

<a id="SEM-STMT-BLOCK"></a>
### Block forms

```kovy
if true: int x = 1

if true:
  int x = 1
  int y = 2
```

The inline form contains exactly one statement. The indented form contains a
sequence and ends at the matching dedent. A function body must be non-empty
when the colon is present; branch and loop bodies may be empty in the indented
form.

## Scope behavior

<a id="SEM-STMT-SCOPE"></a>
### Scope behavior

- `if`/`elif`/`else` bodies each push a branch scope.
- A `while` body pushes a loop scope.
- A function has a parameter scope and then a function-body scope.
- There is no standalone block statement, so no other block scope exists.
- Declarations in a branch or loop disappear after that construct.
- Shadowing an outer name in a nested branch/loop/function body is allowed.

## Statement separators

<a id="SEM-STMT-SEPARATORS"></a>
### Separators

Simple statements require `EOS`. Newline and `;` both provide it. Compound
statements normally end with a dedent. Current parser behavior skips the
separator check after a `branch`, `while`, or `functionDecl`, which can make a
same-line forward declaration followed by another statement legal. A missing
separator between simple statements is `errSyntax`.

## Diagnostics

- [ERR-errDoesNotFit](../errors/errDoesNotFit.md#ERR-errDoesNotFit)
- [ERR-errContextScope](../errors/errContextScope.md#ERR-errContextScope)
- [ERR-errVoidReturnValue](../errors/errVoidReturnValue.md#ERR-errVoidReturnValue)
- [ERR-errReturnValueExpected](../errors/errReturnValueExpected.md#ERR-errReturnValueExpected)
- [ERR-errNotAllPathsReturn](../errors/errNotAllPathsReturn.md#ERR-errNotAllPathsReturn)
- [ERR-errUnreachableCode](../errors/errUnreachableCode.md#ERR-errUnreachableCode)
- [ERR-errIndent](../errors/errIndent.md#ERR-errIndent)
- [ERR-errSyntax](../errors/errSyntax.md#ERR-errSyntax)
- [ERR-errEmptyFunctionBody](../errors/errEmptyFunctionBody.md#ERR-errEmptyFunctionBody)

## Tests

- `tests/tFunc.nim`: return paths, while true, break, unreachable code
- `tests/tSema.nim`: loop context, arrays in loops
- `tests/tPtr.nim`: alloc in branch in a loop, nested function in a loop