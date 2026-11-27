# ERR-errImmutableAssignment

<!-- doc-id: ERR-errImmutableAssignment -->
<!-- kind: errImmutableAssignment -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errImmutableAssignment"></a>
## Message

Locale key: `errImmutableAssignment`.

```text
Cannot assign a value to an immutable expression
  @c0 - is immutable @c1
```

| Placeholder | Meaning |
|---|---|
| `@c0` | left-side expression via `Expr.toStr` |
| `@c1` | left-side type via `Type.toStr` |

No other addinfo.

## Emitters

- `Sema.visit(Binary)` with `tkEquals`: the left expression's type is not
  `typeMutable`.

The check is about the left expression's current write permission, not about
whether some earlier value came from a mutable source. See
[SEM-MUT-WRITE](../language/mutability.md#SEM-MUT-WRITE).

## Triggers

<a id="TRG-errImmutableAssignment-variable"></a>
### TRG-errImmutableAssignment-variable

<!-- expect-errors: errImmutableAssignment -->
```kovy
int x = 1
x = 2
```

A declaration without `mut` creates an immutable symbol.

<a id="TRG-errImmutableAssignment-pointer"></a>
### TRG-errImmutableAssignment-pointer

<!-- expect-errors: errImmutableAssignment -->
```kovy
int* p = alloc 1 of int
#p = 5
```

`alloc` does not grant write permission. The pointer symbol `p` is immutable,
so `#p` is immutable even though the pointee storage is writable memory.

<a id="TRG-errImmutableAssignment-pointer-arithmetic"></a>
### TRG-errImmutableAssignment-pointer-arithmetic

<!-- expect-errors: errImmutableAssignment -->
```kovy
int* p = alloc 1 of int
#(p + 1) = 5
```

Pointer arithmetic inherits the pointer operand's write permission, which is
false here.

<a id="TRG-errImmutableAssignment-addr"></a>
### TRG-errImmutableAssignment-addr

<!-- expect-errors: errImmutableAssignment -->
```kovy
int mut x = 1
#(addr x) = 5
```

`addr` requires a mutable operand, but the resulting pointer expression does
not grant write permission by itself.

<a id="TRG-errImmutableAssignment-alloc"></a>
### TRG-errImmutableAssignment-alloc

<!-- expect-errors: errImmutableAssignment -->
```kovy
#(alloc 1 of int) = 5
```

An allocation expression is not a writable lvalue. Bind it to a mutable
pointer symbol first.

<a id="TRG-errImmutableAssignment-literal"></a>
### TRG-errImmutableAssignment-literal

<!-- expect-errors: errImmutableAssignment -->
```kovy
1 = 2
```

The left side is syntactically an expression, not a storage location, and its
type is not mutable.

<a id="TRG-errImmutableAssignment-immutable-call-result"></a>
### TRG-errImmutableAssignment-immutable-call-result

<!-- expect-errors: errImmutableAssignment -->
```kovy
int* pick(int* p):
  return p

int f(int* p):
  #(pick(p)) = 5
  return 0
```

The function returns `int*` without `mut`, so the call result does not grant
write access.

## Near misses

- `int* mut p = alloc 1 of int` followed by `#p = 5` is accepted.
- `int* mut p = addr x` is required to write through an address.
- A mutable value assigned to an immutable variable is accepted; only
  assignment *to* an immutable expression is rejected.
- `addr` of an immutable expression is `ERR-errAddrFromImmutable` before any
  assignment is checked.

## Cascades

The right side is visited before this error is added, so a right-side error can
appear first. The assignment returns `typeError`; an enclosing declaration does
not add a fit error. The left symbol remains unchanged in the AST.

## Tests

- `tests/tPtr.nim`: immutable pointer write, pointer arithmetic permission,
  `addr` permission, direct allocation, and mutable-return cases

## Related

- [KOVY-MUTABILITY](../language/mutability.md#KOVY-MUTABILITY)
- [SEM-MUT-WRITE](../language/mutability.md#SEM-MUT-WRITE)
- [ERR-errAddrFromImmutable](errAddrFromImmutable.md#ERR-errAddrFromImmutable)
- [ERR-errBinaryMismatch](errBinaryMismatch.md#ERR-errBinaryMismatch)