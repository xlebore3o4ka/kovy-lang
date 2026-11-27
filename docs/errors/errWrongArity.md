# ERR-errWrongArity

<!-- doc-id: ERR-errWrongArity -->
<!-- kind: errWrongArity -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errWrongArity"></a>
## Message

Locale key: `errWrongArity`.

```text
Wrong number of arguments: expected @n1, got @n0
```

| Placeholder | Meaning |
|---|---|
| `@n0` | actual argument count |
| `@n1` | parameter count of the callee type |

The `n` modifier currently renders the raw number; no color is applied.

No addinfo.

## Emitters

- `Sema.visit(Call)`, generic path: the callee is a function type and the
  number of arguments differs from `funcArgTypes.len`.

Only the generic path reports this kind. When the callee is a bare global name
with more than one overload, `resolveOverloadCall` skips candidates whose
parameter count differs and reports `ERR-errNoMatchingOverload` if none remain.

## Triggers

<a id="TRG-errWrongArity-too-many"></a>
### TRG-errWrongArity-too-many

<!-- expect-errors: errWrongArity -->
```kovy
int f(int a):
  return a
int x = f(1, 2)
```

The name has exactly one global overload, so the generic path is used.

<a id="TRG-errWrongArity-too-few"></a>
### TRG-errWrongArity-too-few

<!-- expect-errors: errWrongArity -->
```kovy
int f(int a):
  return a
int x = f()
```

All supplied arguments are visited before the count check.

<a id="TRG-errWrongArity-function-value"></a>
### TRG-errWrongArity-function-value

<!-- expect-errors: errWrongArity -->
```kovy
int f(int a):
  return a
int(int) g = f
int x = g(1, 2)
```

`g` is an ordinary variable with a function type; calls through it always use
the generic path.

<a id="TRG-errWrongArity-overload-set"></a>
### TRG-errWrongArity-overload-set

<!-- expect-errors: errNoMatchingOverload -->
```kovy
int f(int a):
  return a
int f(bool b):
  return 1
int x = f(true, 1)
```

This near miss shows the boundary: with two overloads, no candidate has two
parameters, so the result is `errNoMatchingOverload`, not `errWrongArity`.

## Near misses

- Calling a non-function is `ERR-errNotCallable`.
- A single-overload call with the correct count but an unconvertible argument
  is `ERR-errArgMismatch`.
- An overloaded call with no matching overload is
  `ERR-errNoMatchingOverload`.
- If the callee expression has `typeError`, the call returns early without an
  arity check.

## Cascades

The call returns `typeError`, suppressing an enclosing declaration
`errDoesNotFit`. Arguments are not checked against parameter types, so an
argument's own errors are the only ones that can appear in addition. The callee
is visited before the count check, so a callee error can precede this one.

## Tests

- `tests/tFunc.nim`: direct calls and function values
- `tests/tPtr.nim`: calls through function pointers

## Related

- [SEM-FUNC-CALL](../language/functions.md#SEM-FUNC-CALL)
- [SEM-OVL-RESOLUTION](../language/overloads.md#SEM-OVL-RESOLUTION)
- [ERR-errArgMismatch](errArgMismatch.md#ERR-errArgMismatch)
- [ERR-errNoMatchingOverload](errNoMatchingOverload.md#ERR-errNoMatchingOverload)