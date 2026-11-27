# ERR-errNotAllPathsReturn

<!-- doc-id: ERR-errNotAllPathsReturn -->
<!-- kind: errNotAllPathsReturn -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errNotAllPathsReturn"></a>
## Message

Locale key: `errNotAllPathsReturn`.

```text
Not all control paths return a value
```

No placeholders and no addinfo.

## Emitters

- `Sema.visit(FuncDecl)`: the declaration has a body, its declared return type
  is not `void`, and `controlAllReturnPaths(body)` is false.

The check runs after the body scope is popped. It uses the declared return type
before any mutable wrapper is considered, so both `int` and `int mut` functions
are checked.

## Decision procedure

`controlAllReturnPaths` is syntactic and does not evaluate conditions:

| Node | Returns true when |
|---|---|
| block | any statement in the block returns |
| `return` | always |
| `if` | has an `else` and every `if`/`elif`/`else` body returns |
| `while true` | the condition is the literal boolean `true` and the body contains no syntactic `break` |
| anything else | never |

A block returns if *any* statement returns because earlier statements either
continue to that return or exit the function. This also explains why a
statement after a guaranteed return is unreachable rather than a separate
path.

## Triggers

<a id="TRG-errNotAllPathsReturn-missing-else"></a>
### TRG-errNotAllPathsReturn-missing-else

<!-- expect-errors: errNotAllPathsReturn -->
```kovy
int f(int x):
  if x > 0:
    return x
```

An `if` without `else` is never exhaustive, even when the condition is
literally `true`.

<a id="TRG-errNotAllPathsReturn-empty-body"></a>
### TRG-errNotAllPathsReturn-empty-body

<!-- expect-errors: errNotAllPathsReturn -->
```kovy
int f():
  int x = 1
```

A non-void function whose body contains no return at all is reported.

<a id="TRG-errNotAllPathsReturn-while-condition"></a>
### TRG-errNotAllPathsReturn-while-condition

<!-- expect-errors: errNotAllPathsReturn -->
```kovy
int f():
  while 1 == 1:
    int x = 1
```

Only the literal boolean `true` is recognized as a non-fallthrough condition.

<a id="TRG-errNotAllPathsReturn-while-break"></a>
### TRG-errNotAllPathsReturn-while-break

<!-- expect-errors: errNotAllPathsReturn -->
```kovy
int f():
  while true:
    break
```

A syntactic `break` in the body makes the loop able to fall through, so a
return after the loop is required.

## Near misses

- `if` with a complete `elif` chain and an `else` is accepted when every body
  returns.
- `while true` with no syntactic `break` is accepted, even if the body never
  returns.
- `while true` with a break inside a nested loop or nested function does not
  count as breaking the outer loop.
- A bare `return` in a non-void function still counts as a return for this
  analysis, even though it separately reports `ERR-errReturnValueExpected`.
- A `void` function is never checked.
- A bodyless forward declaration is not checked.

## Cascades

The error is attached to the function declaration token. The body has already
been analyzed, so other body diagnostics can appear before it. The declaration
still exists in the overload table and can be called. Nimgen is not run by the
test driver when this error is present.

## Tests

- `tests/tFunc.nim`: `if`/`else`, `while true`, break, and missing-return cases
- `tests/tSema.nim`: break inside a nested function

## Related

- [SEM-FLOW-RETURN-PATHS](../language/control-flow.md#SEM-FLOW-RETURN-PATHS)
- [SEM-FLOW-EXITS-LOOP](../language/control-flow.md#SEM-FLOW-EXITS-LOOP)
- [ERR-errUnreachableCode](errUnreachableCode.md#ERR-errUnreachableCode)
- [ERR-errReturnValueExpected](errReturnValueExpected.md#ERR-errReturnValueExpected)