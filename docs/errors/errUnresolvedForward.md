# ERR-errUnresolvedForward

<!-- doc-id: ERR-errUnresolvedForward -->
<!-- kind: errUnresolvedForward -->
<!-- status: emitted -->
<!-- phase: sema/finalize -->

<a id="ERR-errUnresolvedForward"></a>
## Message

Locale key: `errUnresolvedForward`.

```text
Forward-declared function @q0 has no definition
```

| Placeholder | Meaning |
|---|---|
| `@q0` | function name |

No addinfo.

## Emitters

- `Sema.finalize`: for every overload in `forwardOrder` whose `defined` flag is
  still false, add this error at the forward declaration's function token.

`finalize` runs once, after the whole tree is visited. `forwardOrder` contains
only global bodyless declarations that were accepted. A forward rejected by
another error never enters the list.

## Triggers

<a id="TRG-errUnresolvedForward-never-defined"></a>
### TRG-errUnresolvedForward-never-defined

<!-- expect-errors: errUnresolvedForward -->
```kovy
int f(int a)
int z = 1
```

The forward is accepted and callable, but no definition follows.

<a id="TRG-errUnresolvedForward-different-parameter-list"></a>
### TRG-errUnresolvedForward-different-parameter-list

<!-- expect-errors: errUnresolvedForward -->
```kovy
int f(int a, int b)
int f(int a):
  return a
```

`findOverload` matches parameter types exactly. The one-parameter definition
does not match the two-parameter forward, so it becomes a separate overload and
the forward stays undefined.

<a id="TRG-errUnresolvedForward-different-parameter-type"></a>
### TRG-errUnresolvedForward-different-parameter-type

<!-- expect-errors: errUnresolvedForward -->
```kovy
int f(int a)
int f(bool a):
  return 1
```

Different parameter types also produce a new overload, not a signature
mismatch.

<a id="TRG-errUnresolvedForward-duplicate-forward"></a>
### TRG-errUnresolvedForward-duplicate-forward

<!-- expect-errors: errFuncRedefinition, errUnresolvedForward -->
```kovy
int f(int a)
int f(int a)
```

The second forward is rejected as a redefinition; the first was never defined.

<a id="TRG-errUnresolvedForward-overload-by-return"></a>
### TRG-errUnresolvedForward-overload-by-return

<!-- expect-errors: errOverloadByReturnType, errUnresolvedForward -->
```kovy
int f()
bool f()
```

The second forward is rejected, leaving the first undefined.

<a id="TRG-errUnresolvedForward-multiple"></a>
### TRG-errUnresolvedForward-multiple

<!-- expect-errors: errUnresolvedForward, errUnresolvedForward -->
```kovy
int f()
bool g()
int z = 1
```

Each undefined forward produces its own diagnostic in declaration order.

## Near misses

- A forward completed by a definition is not reported.
- A definition whose parameter names differ but whose types match reports
  `ERR-errFuncSignatureMismatch` and marks the forward defined, so it is not
  reported here.
- A nested bodyless function is rejected immediately as
  `ERR-errForwardOutsideGlobal` and never enters `forwardOrder`.
- A call to an unresolved forward is still type-checked using the forward
  signature.

## Cascades

`finalize` errors are added after all sema-visit diagnostics, so they appear
last in the context. A program can have valid calls to the unresolved forward.
Nimgen would emit a Nim `proc` forward declaration with no body; the test
driver does not run nimgen once any error exists, so this is not exercised by
the documented snippets.

## Tests

- `tests/tFunc.nim`: unresolved forwards and forward completion

## Related

- [SEM-FUNC-FORWARD](../language/functions.md#SEM-FUNC-FORWARD)
- [ERR-errForwardOutsideGlobal](errForwardOutsideGlobal.md#ERR-errForwardOutsideGlobal)
- [ERR-errFuncSignatureMismatch](errFuncSignatureMismatch.md#ERR-errFuncSignatureMismatch)
- [ERR-errFuncRedefinition](errFuncRedefinition.md#ERR-errFuncRedefinition)