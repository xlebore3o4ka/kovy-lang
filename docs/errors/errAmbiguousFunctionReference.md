# ERR-errAmbiguousFunctionReference

<!-- doc-id: ERR-errAmbiguousFunctionReference -->
<!-- kind: errAmbiguousFunctionReference -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errAmbiguousFunctionReference"></a>
## Message

Locale key: `errAmbiguousFunctionReference`.

```text
Ambiguous reference to function @q0
  Use it in a context with an expected function type
```

| Placeholder | Meaning |
|---|---|
| `@q0` | function name |

The addinfo is always present.

## Emitters

- `Sema.visit(Symbol)`: the name has more than one global overload and no
  expected function type has selected one.

`visitExpected` is the selecting path. If the expected type (after stripping a
mutable wrapper) is a function type, it searches the overload set for an exact
`sameType` signature and sets `resolvedOverloadId`. Otherwise—or when no
overload matches exactly—it falls back to `visit(Symbol)`, which reports this
error.

## Triggers

<a id="TRG-errAmbiguousFunctionReference-initializer"></a>
### TRG-errAmbiguousFunctionReference-initializer

<!-- expect-errors: errAmbiguousFunctionReference -->
```kovy
int f(int a):
  return a
int f(bool b):
  return 1
int x = f
```

The expected initializer type is `int`, not a function type.

<a id="TRG-errAmbiguousFunctionReference-statement"></a>
### TRG-errAmbiguousFunctionReference-statement

<!-- expect-errors: errAmbiguousFunctionReference -->
```kovy
int f(int a):
  return a
int f(bool b):
  return 1
f
```

An expression statement discards the value but still visits the symbol.

<a id="TRG-errAmbiguousFunctionReference-non-function-return"></a>
### TRG-errAmbiguousFunctionReference-non-function-return

<!-- expect-errors: errAmbiguousFunctionReference -->
```kovy
int f(int a):
  return a
int f(bool b):
  return 1
int pick():
  return f
```

The return type is `int`, so it cannot select an overload.

<a id="TRG-errAmbiguousFunctionReference-mismatched-function-type"></a>
### TRG-errAmbiguousFunctionReference-mismatched-function-type

<!-- expect-errors: errAmbiguousFunctionReference -->
```kovy
int f(int a):
  return a
int f(bool b):
  return 1
int(bool, int) g = f
```

Even an expected function type does not help unless it matches an overload
exactly.

## Near misses

- `int(bool) g = f` selects the `int f(bool)` overload with no error.
- A single global overload is resolved by `visit(Symbol)` without an expected
  type.
- Calling an overload set `f(...)` uses `resolveOverloadCall`, not symbol
  resolution; see `ERR-errAmbiguousCall` and `ERR-errNoMatchingOverload`.
- A locally shadowed name is not an overload set; `getGlobalOverloads` requires
  the innermost symbol to be a global function.

## Cascades

The symbol visit returns `typeError`. A declaration initializer therefore does
not add `errDoesNotFit`. A call whose callee symbol is ambiguous returns
`typeError` from the callee visit and does not check arity or arguments. A
return still counts as a return for all-paths-return analysis.

## Tests

- `tests/tFunc.nim`: function values with overload sets
- `tests/tFunc.nim`: expected function type selection

## Related

- [SEM-OVL-RESOLUTION](../language/overloads.md#SEM-OVL-RESOLUTION)
- [SEM-SCOPE-FUNCTIONS](../language/scopes.md#SEM-SCOPE-FUNCTIONS)
- [ERR-errAmbiguousCall](errAmbiguousCall.md#ERR-errAmbiguousCall)
- [ERR-errNoMatchingOverload](errNoMatchingOverload.md#ERR-errNoMatchingOverload)