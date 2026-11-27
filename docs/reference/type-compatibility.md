# Type compatibility

<!-- doc-id: REF-TYPE-COMPAT -->
<!-- status: current -->

<a id="REF-TYPE-COMPAT"></a>
This page is the compact reference for Kovy's three compatibility relations:
`fits`, `conversionCost`, and `sameType`, all implemented in
`src/visitors/sema.nim` and `src/types.nim`. The normative prose lives in
[types](../language/types.md#SEM-TYPE-FITS); this page tabulates the cases.

<a id="REF-TYPE-COMPAT-KINDS"></a>
## Type kinds

| `TypeKind` | Source spelling | Notes |
|---|---|---|
| `typeNumberLit` | integer literal | internal only; diagnostic name `numberLiteral` |
| `typeBoolLit` | `true` / `false` | internal only; diagnostic name `boolLiteral` |
| `typeInt` | `int` | only integer type |
| `typeBool` | `bool` | only boolean type |
| `typeVoid` | `void` | return/function type; no value |
| `typeError` | none | recovery type |
| `typeMutable` | `mut` | wrapper around an inner type |
| `typePtr` | `T*` | pointer to `T` |
| `typeFunc` | `R(A, B)` | function type |

<a id="REF-TYPE-COMPAT-FITS"></a>
## `fits`

`fits(actual, expected)` answers "can this value be assigned or returned
here?" It is used by declarations, returns, array element checks, allocation
counts, and as a fallback inside `conversionCost`.

Decision order:

1. If either side is `typeError`, return true.
2. If `actual` is `typeMutable`, recurse with its inner type.
3. If `expected` is `typeMutable`, recurse with its inner type.
4. If either side is `typeFunc` or `typePtr`, return `sameType(actual,
   expected)`.
5. Otherwise, look up `actual.kind` in the fit set.

| Actual kind | Fits into |
|---|---|
| `typeNumberLit` | `typeNumberLit`, `typeInt` |
| `typeInt` | `typeInt` |
| `typeBoolLit` | `typeBoolLit`, `typeBool` |
| `typeBool` | `typeBool` |
| `typeVoid` | nothing |
| `typePtr` | identical pointer type only |
| `typeFunc` | identical function type only |
| `typeError` | everything (both directions) |

<a id="REF-TYPE-COMPAT-FITS-MATRIX"></a>
### Scalar matrix

Rows are actual types, columns are expected types. `yes` means `fits` returns
true; `no` means false.

| actual \ expected | `numberLit` | `int` | `boolLit` | `bool` | `void` |
|---|---|---|---|---|---|
| `numberLit` | yes | yes | no | no | no |
| `int` | no | yes | no | no | no |
| `boolLit` | no | no | yes | yes | no |
| `bool` | no | no | no | yes | no |
| `void` | no | no | no | no | no |

A `mut T` on either side is stripped before this table is consulted, so
`mut int` fits `int` and `int` fits `mut int` under `fits`. `conversionCost`
is stricter about mutability; see below.

<a id="REF-TYPE-COMPAT-COST"></a>
## `conversionCost`

`conversionCost(actual, expected)` is the call-site relation used for overload
ranking and argument checks:

| Result | Meaning |
|---|---|
| `-1` | cannot convert |
| `0` | exact match |
| `1` or more | accepted conversion; larger is worse |

Decision order:

1. If either side is `typeError`, return `0`.
2. If `expected` is `typeMutable`: the actual must also be `typeMutable`;
   otherwise return `-1`. Recurse on the inner types.
3. If `actual` is `typeMutable`: compute the cost to the inner type against
   `expected`; if that is `-1`, return `-1`; otherwise return `1 + inner`.
4. If `sameType(actual, expected)`, return `0`.
5. If `fits(actual, expected)`, return `1`.
6. Otherwise return `-1`.

| Actual | Expected | Cost | Reason |
|---|---|---|---|
| `int` | `int` | 0 | exact |
| `numberLit` | `int` | 1 | fits |
| `boolLit` | `bool` | 1 | fits |
| `mut int` | `int` | 1 | mutability dropped |
| `mut int` | `mut int` | 0 | exact |
| `int` | `mut int` | -1 | mutable expected, immutable actual |
| `bool` | `int` | -1 | no cross-family conversion |
| `int*` | `int*` | 0 | identical pointer |
| `int*` | `bool*` | -1 | pointers compare exactly |
| `int(int)` | `int(bool)` | -1 | functions compare exactly |

A mutable argument can be passed to an immutable parameter, but not the other
way around. Dropping mutability adds one to the cost. This is why two
overloads can tie and produce `ERR-errAmbiguousCall`.

<a id="REF-TYPE-COMPAT-SAME"></a>
## `sameType`

`sameType(a, b)` is structural and exact:

- kinds must match;
- for functions: return type and every argument type must match, including
  parameter mutability;
- for pointers: the pointee type must match recursively;
- for other kinds: names must match, and arguments must match recursively;
- a mutable type is **not** equal to its inner type.

There is no variance, no subtyping, and no implicit pointer conversion.
`int*` and `void*` are different types, and `int(int)` and `int(mut int)` are
different function types.

<a id="REF-TYPE-COMPAT-LITERALS"></a>
## Literal typing

- A number literal has `typeNumberLit` until a concrete expectation converts
  it to `int`.
- A boolean literal has `typeBoolLit` until a concrete expectation converts
  it to `bool`.
- Binary arithmetic always returns concrete `int`, even when both operands
  are literals. `1 + 2` is `int`, not `numberLit`.
- Ordered comparisons and equality return `bool`.
- Unary `+` and `-` on a number literal return `int`; `not` on a boolean
  literal returns `bool`.
- An array literal without `of T` infers its element type from the first
  element, stripping a mutable wrapper. An explicit `of T` uses `T` for every
  element and checks each with `fits`.

<a id="REF-TYPE-COMPAT-PTRFUNC"></a>
## Pointers, functions, and `void`

- `T*` is compatible only with the identical `T*`. Nesting is allowed:
  `int**` is a pointer to `int*`.
- `R(A, B)` is compatible only with the identical function type. A mutable
  parameter is written `mut T` and participates in equality.
- `void*` is a valid sema type but not a concrete Nim type. Code generation
  reports `ERR-errNonConcreteType` when it must emit such a pointer.
- `void` does not fit `void` through the scalar table. Function return
  handling special-cases `void` before calling `fits`.

<a id="REF-TYPE-COMPAT-ERROR"></a>
## Error type

`typeError` is a recovery marker. `fits` returns true when either side is
`typeError`, and `conversionCost` returns `0`. This suppresses cascading type
errors after an earlier diagnostic. It does not make an error-typed value
legal; it only stops a second diagnostic.

## Related

- [Types](../language/types.md#SEM-TYPE-FITS)
- [Type model internals](../internals/types.md#INT-TYPES-KINDS)
- [Overload resolution](../language/overloads.md#SEM-OVL-RESOLUTION)
- [ERR-errDoesNotFit](../errors/errDoesNotFit.md#ERR-errDoesNotFit)
- [ERR-errArgMismatch](../errors/errArgMismatch.md#ERR-errArgMismatch)