# ERR-errAddrFromImmutable

<!-- doc-id: ERR-errAddrFromImmutable -->
<!-- kind: errAddrFromImmutable -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errAddrFromImmutable"></a>
## Message

Locale key: `errAddrFromImmutable`.

```text
Cannot take the address of an immutable expression
  @c0 is not mutable
```

| Placeholder | Meaning |
|---|---|
| `@c0` | operand expression via `Expr.toStr` |

There is no placeholder in the message line; the addinfo is always present.

## Emitters

- `Sema.visit(Unary)` with `tkAddr`: the visited operand type is not
  `typeMutable`.

The diagnostic is attached to the operand token. Taking an address does not
grant write permission: the result is `ptr T` with `grantsWrite = false`, so it
must be stored in a `mut` pointer before writing through it.

## Triggers

<a id="TRG-errAddrFromImmutable-literal"></a>
### TRG-errAddrFromImmutable-literal

<!-- expect-errors: errAddrFromImmutable -->
```kovy
int* p = addr 1
```

A literal is not a storage location.

<a id="TRG-errAddrFromImmutable-immutable-variable"></a>
### TRG-errAddrFromImmutable-immutable-variable

<!-- expect-errors: errAddrFromImmutable -->
```kovy
int x = 1
int* p = addr x
```

A declaration without `mut` is immutable.

<a id="TRG-errAddrFromImmutable-alloc"></a>
### TRG-errAddrFromImmutable-alloc

<!-- expect-errors: errAddrFromImmutable -->
```kovy
int* p = addr (alloc 1 of int)
```

An allocation expression does not grant write permission by itself.

<a id="TRG-errAddrFromImmutable-immutable-deref"></a>
### TRG-errAddrFromImmutable-immutable-deref

<!-- expect-errors: errAddrFromImmutable -->
```kovy
int* p = alloc 1 of int
int* q = addr #p
```

`p` is an immutable pointer symbol, so `#p` is immutable.

<a id="TRG-errAddrFromImmutable-immutable-call"></a>
### TRG-errAddrFromImmutable-immutable-call

<!-- expect-errors: errAddrFromImmutable -->
```kovy
int f():
  return 1
int* p = addr f()
```

The call result is a plain `int`, not a mutable value.

<a id="TRG-errAddrFromImmutable-operator-result"></a>
### TRG-errAddrFromImmutable-operator-result

<!-- expect-errors: errAddrFromImmutable -->
```kovy
int x = 1
int* p = addr (x + 1)
```

An arithmetic result is a temporary, not a mutable location.

## Near misses

- `int mut x` followed by `addr x` is accepted.
- `addr #p` is accepted when `p` is a mutable pointer, because the dereference
  inherits write permission.
- `addr (x = 2)` is accepted when `x` is mutable; an assignment expression has
  mutable result type.
- `addr` of a mutable call result is accepted when the callee's return type is
  mutable.
- `#(addr x)` is valid but does not grant write permission; assigning through
  that dereference is `ERR-errImmutableAssignment`.

## Cascades

The unary expression returns `typeError`, suppressing an enclosing
`errDoesNotFit`. The operand is visited first, so its diagnostics can precede
this one. The check runs before any assignment or pointer-arithmetic use.

## Tests

- `tests/tPtr.nim`: `addr` of mutable and immutable expressions
- `tests/tPtr.nim`: write permission after `addr`

## Related

- [SYN-EXPR-UNARY](../language/expressions.md#SYN-EXPR-UNARY)
- [SEM-PTR-RULES](../language/pointers.md#SEM-PTR-RULES)
- [KOVY-MUTABILITY](../language/mutability.md#KOVY-MUTABILITY)
- [ERR-errImmutableAssignment](errImmutableAssignment.md#ERR-errImmutableAssignment)
- [ERR-errDerefNonPointer](errDerefNonPointer.md#ERR-errDerefNonPointer)