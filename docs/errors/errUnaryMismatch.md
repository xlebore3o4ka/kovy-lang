# ERR-errUnaryMismatch

<!-- doc-id: ERR-errUnaryMismatch -->
<!-- kind: errUnaryMismatch -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errUnaryMismatch"></a>
## Message

Locale key: `errUnaryMismatch`.

```text
Unary type mismatch for @0 with type @1
```

| Placeholder | Meaning |
|---|---|
| `@0` | operator description (`Token.mean`) |
| `@1` | operand type via `Type.toStr`, including `mutable[T]` |

No addinfo.

## Emitters

- `Sema.visit(Unary)` for unary operators other than `#` and `addr`: the
  operand kind is absent from `unOpResult`.

`#` has its own `ERR-errDerefNonPointer` path, and `addr` has its own
`ERR-errAddrFromImmutable` path.

## Accepted unary forms

| Operator | Operand | Result |
|---|---|---|
| `+` | number literal or `int` | `int` |
| `-` | number literal or `int` | `int` |
| `not` | bool literal or `bool` | `bool` |

Mutable wrappers are stripped before the lookup. A pointer, `void`, function
type, or the opposite scalar family is rejected. There is no unary operator
for pointers, bitwise complement, or logical `!`.

## Triggers

<a id="TRG-errUnaryMismatch-numeric-on-bool"></a>
### TRG-errUnaryMismatch-numeric-on-bool

<!-- expect-errors: errUnaryMismatch -->
```kovy
int x = -true
```

`-` accepts integer-like operands only. `+true` uses the same path.

<a id="TRG-errUnaryMismatch-not-on-int"></a>
### TRG-errUnaryMismatch-not-on-int

<!-- expect-errors: errUnaryMismatch -->
```kovy
int x = not 1
```

`not` accepts boolean-like operands only.

<a id="TRG-errUnaryMismatch-pointer-operand"></a>
### TRG-errUnaryMismatch-pointer-operand

<!-- expect-errors: errUnaryMismatch -->
```kovy
int* p
int* q = +p
```

Unary `+` does not accept pointers. To advance a pointer, use pointer
arithmetic with an integer.

<a id="TRG-errUnaryMismatch-mutable-operand"></a>
### TRG-errUnaryMismatch-mutable-operand

<!-- expect-errors: errUnaryMismatch -->
```kovy
int mut x = 1
bool b = not x
```

The mutable wrapper is stripped for the table lookup; the inner `int` still
does not fit `not`.

## Near misses

- `#p` on a pointer is valid and returns the pointee.
- `addr x` on a mutable expression is valid even though `addr` is unary.
- An error-typed operand returns immediately without this error.
- Mutable integer operands are accepted by `+` and `-`.

## Cascades

The expression returns `typeError`, so a declaration initializer does not add
`errDoesNotFit`. `Type.toStr` in the message can display `mutable[int]`, unlike
the `mut int` form used by some other sema diagnostics.

## Tests

- `tests/tPtr.nim`: unary `#` and `addr` are tested separately
- `tests/tFunc.nim`: integer and boolean expressions

## Related

- [SYN-EXPR-UNARY](../language/expressions.md#SYN-EXPR-UNARY)
- [ERR-errDerefNonPointer](errDerefNonPointer.md#ERR-errDerefNonPointer)
- [ERR-errAddrFromImmutable](errAddrFromImmutable.md#ERR-errAddrFromImmutable)