# ERR-errOverloadByReturnType

<!-- doc-id: ERR-errOverloadByReturnType -->
<!-- kind: errOverloadByReturnType -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errOverloadByReturnType"></a>
## Message

Locale key: `errOverloadByReturnType`.

```text
Cannot overload @q0 by return type only
  First: @c1
  Second: @c2
```

| Placeholder | Meaning |
|---|---|
| `@q0` | function name |
| `@c1` | signature of the earlier declaration |
| `@c2` | signature of the rejected declaration |

Both signatures use `signatureStr`, including parameter names and mutable
markers.

## Emitters

- `Sema.visit(FuncDecl)`: a bodyless declaration has the same parameter types
  as an existing, still-undefined overload but a different return type.
- `Sema.visit(FuncDecl)`: a definition has the same parameter types as an
  existing, already-defined overload but a different return type.

The earlier declaration remains authoritative. When the earlier one was a
forward, it can additionally be reported by `finalize` as unresolved.

## Triggers

<a id="TRG-errOverloadByReturnType-forwards"></a>
### TRG-errOverloadByReturnType-forwards

<!-- expect-errors: errOverloadByReturnType, errUnresolvedForward -->
```kovy
int f()
bool f()
```

Both are forwards with identical parameter lists. The second is rejected, and
the first is never defined.

<a id="TRG-errOverloadByReturnType-definitions"></a>
### TRG-errOverloadByReturnType-definitions

<!-- expect-errors: errOverloadByReturnType -->
```kovy
int f():
  return 1
bool f():
  return true
```

Two definitions with identical parameter lists and different return types.

<a id="TRG-errOverloadByReturnType-mutable-return"></a>
### TRG-errOverloadByReturnType-mutable-return

<!-- expect-errors: errOverloadByReturnType -->
```kovy
int f():
  return 1
int mut f():
  return 2
```

The mutable return wrapper is part of the return type, so this is still an
overload by return type alone.

<a id="TRG-errOverloadByReturnType-pointer-return"></a>
### TRG-errOverloadByReturnType-pointer-return

<!-- expect-errors: errOverloadByReturnType -->
```kovy
int f():
  return 1
int* f():
  return alloc 1 of int
```

`int` and `int*` differ only in the return type.

## Near misses

- A definition matching an **undefined forward** with the same parameter types
  but a different return type is `ERR-errFuncSignatureMismatch`, not this
  error. The direction matters: a forward followed by its mismatched
  definition is a failed completion, not a new overload.
- A duplicate declaration with the same parameter types and the same return
  type is `ERR-errFuncRedefinition`.
- A declaration with different parameter types is a valid overload and is
  accepted.
- Parameter **names** do not distinguish overloads; they are checked only when
  completing a forward.

## Cascades

The rejected declaration is not added to the overload table and is not
analyzed further. If the earlier declaration was a forward, it stays undefined
and `finalize` adds `errUnresolvedForward`. If the earlier declaration was a
definition, it remains callable. Later statements continue normally.

## Tests

- `tests/tFunc.nim`: return-type-only overload rejection

## Related

- [SEM-OVL-SIGNATURE](../language/overloads.md#SEM-OVL-SIGNATURE)
- [SEM-FUNC-FORWARD](../language/functions.md#SEM-FUNC-FORWARD)
- [ERR-errFuncRedefinition](errFuncRedefinition.md#ERR-errFuncRedefinition)
- [ERR-errFuncSignatureMismatch](errFuncSignatureMismatch.md#ERR-errFuncSignatureMismatch)