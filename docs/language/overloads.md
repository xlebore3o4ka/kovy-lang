# Overloads

<!-- doc-id: KOVY-OVERLOADS -->
<!-- status: current -->

<a id="KOVY-OVERLOADS"></a>
Only global functions participate in overloading. Nested functions cannot be
overloaded. A global overload set is keyed by name and contains declarations
whose parameter types differ.

## Signature and validity

<a id="SEM-OVL-SIGNATURE"></a>
### Signature

An overload signature contains:

- return type, including mutable return;
- each parameter type, including parameter mutability.

Overload identity for duplicate detection compares parameter types only
(`sameParams`). Two declarations with the same parameter types are not distinct
overloads:

- two definitions, or two forwards, with identical parameter types and the same
  return type: the later one is `ERR-errFuncRedefinition`;
- the same, but with different return types: the later one is
  `ERR-errOverloadByReturnType`;
- a definition after a forward with identical parameter types must additionally
  match the return type and parameter names; otherwise it is
  `ERR-errFuncSignatureMismatch`.

Different parameter mutability, parameter count, or parameter types create
different overloads. In particular, a definition whose parameter types differ
from a forward's does not complete that forward; the forward remains
`ERR-errUnresolvedForward`.

```kovy
int f(int a):
  return a

int f(bool a):
  return 1
```

## Call-site resolution

<a id="SEM-OVL-RESOLUTION"></a>
### Resolution algorithm

When the callee is a bare symbol with more than one global overload:

1. Visit each argument without an expected parameter type.
2. Reject candidates whose arity differs.
3. Compute `conversionCost(actual, expected)` for each argument.
4. Sum the costs. Any `-1` rejects that candidate.
5. Keep the candidate(s) with the minimum total cost.
6. One winner: resolve and return its return type.
7. Multiple winners: `ERR-errAmbiguousCall`.
8. No winner: `ERR-errNoMatchingOverload`.

When there is exactly one overload, the generic call path is used instead:
the callee symbol resolves to the function type, arity errors are
`errWrongArity`, and argument errors are `errArgMismatch`.

## Cost examples

<a id="SEM-OVL-COSTS"></a>
| Actual | Expected | Cost |
|---|---|---|
| exact `int` | `int` | 0 |
| number literal | `int` | 1 |
| mutable `int` | `int` | 1 |
| mutable `int` | mutable `int` | 0 |
| immutable `int` | mutable `int` | -1 |

A more specific candidate wins. For example, a mutable argument prefers a
`mut` parameter over a by-value parameter because the mutable-to-immutable
conversion adds `1`.

## Function references

<a id="SEM-OVL-REFERENCES"></a>
### Expected function types

A bare function name with one overload resolves immediately. A bare name with
multiple overloads needs an expected function type:

```kovy
int f(int a):
  return a

int f(bool a):
  return 1

int(int) g = f
int x = g(1)
```

The expected type is compared with `sameType`; this is exact, including
parameter mutability. Without an expected function type, an overloaded
reference is `ERR-errAmbiguousFunctionReference`.

A function reference can also be used as an argument when the parameter type
is a function type; `visitExpected` selects the exact overload.

## Forward declarations

<a id="SEM-OVL-FORWARD"></a>
### Forwards

Forward declarations add their signature to the overload table immediately.
A matching definition fills the existing entry. A definition with different
parameter types creates a new overload and leaves the forward unresolved,
which is reported by `finalize`.

## Current limitations

<a id="SEM-OVL-LIMITS"></a>
- Overloads are global-only. A nested function cannot shadow any visible name
  and cannot be overloaded. A function-name collision is
  `errFuncRedefinition`; a collision with a variable or parameter is
  `errRedeclaration`.
- There is no overload by return type.
- There are no named or default arguments to help resolution.
- `errAmbiguousCall` is reachable when two overloads tie at the minimum
  conversion cost. The canonical trigger uses crossed mutable parameters. See
  [ERR-errAmbiguousCall](../errors/errAmbiguousCall.md#ERR-errAmbiguousCall).
- Function types are compared exactly; there is no variance or coercion.

## Examples

<a id="EX-OVL-BASIC"></a>
<!-- expect-errors: OK -->
```kovy
int f(int a):
  return a

int f(bool a):
  return 1

int x = f(1)
int y = f(true)
```

<a id="EX-OVL-REFERENCE"></a>
<!-- expect-errors: OK -->
```kovy
int f(int a):
  return a

int f(bool a):
  return 1

int(int) g = f
int x = g(1)
```

<a id="EX-OVL-AMBIGUOUS"></a>
<!-- expect-errors: errAmbiguousFunctionReference -->
```kovy
int f(int a):
  return a

int f(bool a):
  return 1

int x = f
```

<a id="EX-OVL-NO-MATCH"></a>
<!-- expect-errors: errNoMatchingOverload -->
```kovy
int f(int a):
  return a

int f(bool a):
  return 1

int* p = alloc 1 of int
int x = f(p)
```

## Diagnostics

- [ERR-errFuncRedefinition](../errors/errFuncRedefinition.md#ERR-errFuncRedefinition)
- [ERR-errOverloadByReturnType](../errors/errOverloadByReturnType.md#ERR-errOverloadByReturnType)
- [ERR-errUnresolvedForward](../errors/errUnresolvedForward.md#ERR-errUnresolvedForward)
- [ERR-errFuncSignatureMismatch](../errors/errFuncSignatureMismatch.md#ERR-errFuncSignatureMismatch)
- [ERR-errNoMatchingOverload](../errors/errNoMatchingOverload.md#ERR-errNoMatchingOverload)
- [ERR-errAmbiguousCall](../errors/errAmbiguousCall.md#ERR-errAmbiguousCall)
- [ERR-errAmbiguousFunctionReference](../errors/errAmbiguousFunctionReference.md#ERR-errAmbiguousFunctionReference)
- [ERR-errWrongArity](../errors/errWrongArity.md#ERR-errWrongArity)
- [ERR-errArgMismatch](../errors/errArgMismatch.md#ERR-errArgMismatch)

## Tests

- `tests/tFunc.nim`: overload resolution, expected types, ambiguous references,
  void overload selection
- `tests/tPtr.nim`: overloaded runtime names