# ERR-errNoMatchingOverload

<!-- doc-id: ERR-errNoMatchingOverload -->
<!-- kind: errNoMatchingOverload -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errNoMatchingOverload"></a>
## Message

Locale key: `errNoMatchingOverload`.

```text
No overload of @q0 matches arguments (@1)
  @2
```

| Placeholder | Meaning |
|---|---|
| `@q0` | function name |
| `@1` | actual argument types via `diagnosticTypeStr` |
| `@2` | every declared overload via `overloadList` |

The addinfo lists **all** recorded overloads, not only near misses. Each line
is `<file> <line> - <signature>`.

## Emitters

- `Sema.resolveOverloadCall`: the callee is a bare global name with more than
  one overload and no candidate passed both the arity filter and the
  per-argument `conversionCost >= 0` check.

## Triggers

<a id="TRG-errNoMatchingOverload-arity"></a>
### TRG-errNoMatchingOverload-arity

<!-- expect-errors: errNoMatchingOverload -->
```kovy
int f(int a):
  return a
int f(bool b):
  return 1
int x = f(true, 1)
```

Both overloads take one parameter, so both are skipped for arity. This is the
overload-path counterpart of `ERR-errWrongArity`.

<a id="TRG-errNoMatchingOverload-type"></a>
### TRG-errNoMatchingOverload-type

<!-- expect-errors: errNoMatchingOverload -->
```kovy
int f(int a):
  return a
int f(bool b):
  return 1
int x = f([1, 2])
```

An `int*` converts to neither `int` nor `bool`, so there is no candidate.

<a id="TRG-errNoMatchingOverload-mutability"></a>
### TRG-errNoMatchingOverload-mutability

<!-- expect-errors: errNoMatchingOverload -->
```kovy
int f(int mut a):
  return a
int f(bool mut a):
  return 1
int x = f(1)
```

An immutable literal cannot convert to a mutable parameter, and `int` is not a
`bool`, so neither overload matches.

<a id="TRG-errNoMatchingOverload-all-overloads-listed"></a>
### TRG-errNoMatchingOverload-all-overloads-listed

<!-- expect-errors: errNoMatchingOverload -->
```kovy
int f(int a):
  return a
int f(bool b):
  return 1
int f(int* p):
  return 2
int x = f(true, false)
```

The addinfo lists all three overloads even though the failure is an arity
mismatch for every one of them.

## Near misses

- With exactly one global overload, the generic call path is used; arity and
  type failures are `ERR-errWrongArity` and `ERR-errArgMismatch`.
- When several overloads tie at the minimum cost, the result is
  `ERR-errAmbiguousCall`.
- An argument whose visit returns `typeError` aborts resolution before any
  overload diagnostic.
- A name that is not a global function is not resolved through the overload
  table; a non-callable value is `ERR-errNotCallable`.

## Cascades

The call returns `typeError`. All arguments have already been visited once, so
their errors can precede this diagnostic. The overload list is generated from
the recorded declarations, including forwards. The test driver does not run
nimgen after this error.

## Tests

- `tests/tFunc.nim`: overload sets and no-match cases

## Related

- [SEM-OVL-RESOLUTION](../language/overloads.md#SEM-OVL-RESOLUTION)
- [ERR-errAmbiguousCall](errAmbiguousCall.md#ERR-errAmbiguousCall)
- [ERR-errWrongArity](errWrongArity.md#ERR-errWrongArity)
- [ERR-errArgMismatch](errArgMismatch.md#ERR-errArgMismatch)