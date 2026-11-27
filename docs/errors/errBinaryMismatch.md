# ERR-errBinaryMismatch

<!-- doc-id: ERR-errBinaryMismatch -->
<!-- kind: errBinaryMismatch -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errBinaryMismatch"></a>
## Message

Locale key: `errBinaryMismatch`.

```text
Binary type mismatch for @0: @c1
```

| Placeholder | Meaning |
|---|---|
| `@0` | operator description (`Token.mean`) |
| `@1` | a `left operator right` type string |

No addinfo.

## Emitters

- `Sema.visit(Binary)` with `tkEquals`: the right side does not fit the inner
  type of the mutable left side.
- `Sema.visit(Binary)`: a pointer operand combination is invalid.
- `Sema.visit(Binary)`: a scalar operand pair is absent from `binOpResult`.

`ERR-errImmutableAssignment` is used instead when the left side of `=` is not
mutable.

## Accepted binary forms

| Operator | Accepted operands | Result |
|---|---|---|
| `+`, `-`, `*`, `/` | two number literals or `int` values | `int` |
| `<`, `>`, `<=`, `>=` | two number literals or `int` values | `bool` |
| `==`, `!=` | two integer-like or two boolean-like values | `bool` |
| `and`, `or` | two boolean-like values | `bool` |
| `+` | pointer + integer, integer + pointer | pointer type |
| `-` | pointer - integer | pointer type |
| `-` | two pointers of identical type | `int` |
| `=` | mutable lvalue and fitting right side | mutable inner type |

Mutable wrappers are stripped before scalar lookup. Pointer operands are never
accepted by the scalar table, and pointer comparisons are rejected.

## Triggers

<a id="TRG-errBinaryMismatch-scalar-operands"></a>
### TRG-errBinaryMismatch-scalar-operands

<!-- expect-errors: errBinaryMismatch -->
```kovy
int x = 1 + true
```

There is no `(numberLiteral, boolLiteral)` entry for `+`. Other examples:
`true + false`, `1 == true`, and pointer comparison.

<a id="TRG-errBinaryMismatch-assignment-rhs"></a>
### TRG-errBinaryMismatch-assignment-rhs

<!-- expect-errors: errBinaryMismatch -->
```kovy
int mut x = 1
x = true
```

The left side is mutable, so this is the assignment fit-check branch rather
than `errImmutableAssignment`. The right side does not fit `int`.

<a id="TRG-errBinaryMismatch-pointer-combination"></a>
### TRG-errBinaryMismatch-pointer-combination

<!-- expect-errors: errBinaryMismatch -->
```kovy
int f(int* p):
  return 1 - p
```

`int - pointer` is not one of the pointer forms. The same emitter covers
pointer + pointer, pointer * integer, pointer comparison, and pointer
difference with different pointee types.

<a id="TRG-errBinaryMismatch-pointer-offset-type"></a>
### TRG-errBinaryMismatch-pointer-offset-type

<!-- expect-errors: errBinaryMismatch -->
```kovy
int* f(int* p):
  return p + true
```

The offset expression must fit `int`; a boolean literal does not.

## Near misses

- A literal versus `int` pair is accepted.
- A mutable value versus its inner type is accepted after stripping the
  mutable wrapper.
- Pointer difference of the same pointer type is accepted and yields `int`.
- An error-typed operand returns immediately without this error.
- Assignment to an immutable left side is `ERR-errImmutableAssignment`.

## Cascades

The expression returns `typeError`, which suppresses later type errors.
When this occurs in a declaration initializer, the declaration does not add
`errDoesNotFit`. In a return, the return still counts for all-paths analysis.
Only the first invalid scalar pair in a larger expression is reported because
the error type aborts the enclosing binary check.

## Tests

- `tests/tPtr.nim`: valid pointer arithmetic; `int - ptr`, `ptr + ptr`,
  different pointer difference, and pointer comparison rejection
- `tests/tSema.nim`: array mismatch uses `errDoesNotFit`, not this error

## Related

- [SYN-EXPR-BINARY](../language/expressions.md#SYN-EXPR-BINARY)
- [SEM-PTR-ARITHMETIC](../language/pointers.md#SEM-PTR-ARITHMETIC)
- [ERR-errDoesNotFit](errDoesNotFit.md#ERR-errDoesNotFit)
- [ERR-errImmutableAssignment](errImmutableAssignment.md#ERR-errImmutableAssignment)