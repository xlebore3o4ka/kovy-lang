# ERR-errArgMismatch

<!-- doc-id: ERR-errArgMismatch -->
<!-- kind: errArgMismatch -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errArgMismatch"></a>
## Message

Locale key: `errArgMismatch`.

```text
Argument @c0 has type @c1, expected @c2
```

| Placeholder | Meaning |
|---|---|
| `@c0` | argument expression via `Expr.toStr` |
| `@c1` | actual type via `diagnosticTypeStr` (`mut T` form) |
| `@c2` | parameter type via `diagnosticTypeStr` |

No addinfo.

## Emitters

- `Sema.visit(Call)`, generic path: `conversionCost(actual, parameter) < 0`
  for the first failing argument.

The check uses the same conversion cost as overload resolution, not plain
`fits`. Immutable-to-mutable is rejected here even though a mutable-to-
immutable argument is allowed.

## Triggers

<a id="TRG-errArgMismatch-scalar"></a>
### TRG-errArgMismatch-scalar

<!-- expect-errors: errArgMismatch -->
```kovy
int f(int a):
  return a
int x = f(true)
```

`boolLiteral` cannot convert to `int`.

<a id="TRG-errArgMismatch-pointer"></a>
### TRG-errArgMismatch-pointer

<!-- expect-errors: errArgMismatch -->
```kovy
int f(int* a):
  return 1
int x = f(1)
```

A number literal cannot convert to `int*`. Pointer and function types use exact
`sameType` compatibility apart from the outer mutable wrapper.

<a id="TRG-errArgMismatch-mutable-parameter"></a>
### TRG-errArgMismatch-mutable-parameter

<!-- expect-errors: errArgMismatch -->
```kovy
int f(int mut a):
  return a
int x = f(1)
```

A mutable parameter requires a mutable argument; an immutable value is
rejected. Converting a mutable argument to an immutable parameter is allowed.

<a id="TRG-errArgMismatch-first-only"></a>
### TRG-errArgMismatch-first-only

<!-- expect-errors: errArgMismatch -->
```kovy
int f(int a, bool b):
  return a
int x = f(true, 1)
```

Only the first failing argument is reported; the call check aborts after it.

## Near misses

- A number literal converts to `int`, and a boolean literal to `bool`, at cost
  1.
- A mutable value converts to its inner type at cost 1.
- With more than one global overload, an unmatched call is
  `ERR-errNoMatchingOverload`, not this error.
- A call with the wrong number of arguments is `ERR-errWrongArity`.
- An argument whose own visit returns `typeError` stops the call check without
  this error.

## Cascades

The call returns `typeError`, suppressing an enclosing `errDoesNotFit`.
Arguments after the first failing one are not visited by the generic path, so
their own errors are not reported. In the overload path all arguments are
visited first, and an error-typed argument aborts resolution before any
argument-mismatch or overload diagnostic.

## Tests

- `tests/tFunc.nim`: parameter type and mutability checks
- `tests/tPtr.nim`: pointer and function-pointer arguments

## Related

- [SEM-FUNC-CALL](../language/functions.md#SEM-FUNC-CALL)
- [SEM-TYPE-CONVERSION-COST](../language/types.md#SEM-TYPE-CONVERSION-COST)
- [ERR-errWrongArity](errWrongArity.md#ERR-errWrongArity)
- [ERR-errNoMatchingOverload](errNoMatchingOverload.md#ERR-errNoMatchingOverload)