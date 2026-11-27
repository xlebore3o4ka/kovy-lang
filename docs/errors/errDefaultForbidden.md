# ERR-errDefaultForbidden

<!-- doc-id: ERR-errDefaultForbidden -->
<!-- kind: errDefaultForbidden -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errDefaultForbidden"></a>
## Message

Locale key: `errDefaultForbidden`.

```text
Parameter @q0 cannot have a default value
  Default parameter values are not supported
```

| Placeholder | Meaning |
|---|---|
| `@q0` | parameter name |

The addinfo is always present.

## Emitters

- `Sema.visit(FuncDecl)`, parameter pre-pass: a parameter declaration entry has
  a non-nil initializer.

Every parameter with a default gets one diagnostic. The error is reported
before parameter scopes or body analysis. After reporting, sema clears the
default from the AST and treats the parameter as required, so no default value
reaches code generation.

## Triggers

<a id="TRG-errDefaultForbidden-single"></a>
### TRG-errDefaultForbidden-single

<!-- expect-errors: errDefaultForbidden -->
```kovy
int f(int a = 1):
  return a
```

The parameter is still required after the error; the body is analyzed normally.

<a id="TRG-errDefaultForbidden-multiple"></a>
### TRG-errDefaultForbidden-multiple

<!-- expect-errors: errDefaultForbidden, errDefaultForbidden -->
```kovy
int f(int a = 1, int b = 2):
  return a
```

Each entry produces its own diagnostic.

<a id="TRG-errDefaultForbidden-forward"></a>
### TRG-errDefaultForbidden-forward

<!-- expect-errors: errDefaultForbidden -->
```kovy
int f(int a = 1)
int f(int a):
  return a
```

Forwards are checked too. Clearing the default here lets the later definition
complete the forward normally.

<a id="TRG-errDefaultForbidden-nested"></a>
### TRG-errDefaultForbidden-nested

<!-- expect-errors: errDefaultForbidden -->
```kovy
void outer():
  int inner(int a = 1):
    return a
```

Nested functions use the same parameter path.

<a id="TRG-errDefaultForbidden-pointer-default"></a>
### TRG-errDefaultForbidden-pointer-default

<!-- expect-errors: errDefaultForbidden -->
```kovy
int f(int* a = alloc 1 of int):
  return 1
```

Defaults are forbidden regardless of the parameter type or initializer.

## Near misses

- A parameter without `=` has no default and is accepted.
- A default expression is not visited: `int f(int a = missing)` reports only
  this error, not `errUnknownSymbol`.
- A bodyless nested function reports `ERR-errForwardOutsideGlobal`, but the
  parameter default pre-pass runs first, so a default there also reports this
  error.

## Cascades

A default error does **not** stop the function: after clearing the value, sema
continues with parameter declarations, the body, and the all-paths-return
check. A default expression that would otherwise be invalid cannot produce
additional diagnostics because it is removed before the declaration is
visited. Because the parameter becomes required, later calls with fewer
arguments can report arity or overload errors.

## Tests

- `tests/tFunc.nim`: default parameter rejection

## Related

- [SYN-FUNC-PARAMS](../language/functions.md#SYN-FUNC-PARAMS)
- [SEM-FUNC-FORWARD](../language/functions.md#SEM-FUNC-FORWARD)
- [ERR-errForwardOutsideGlobal](errForwardOutsideGlobal.md#ERR-errForwardOutsideGlobal)