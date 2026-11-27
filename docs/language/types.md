# Types

<!-- doc-id: KOVY-TYPES -->
<!-- status: current -->

<a id="KOVY-TYPES"></a>
Kovy has three source-level scalar types, pointer types, function types, and a
contextual `mut` wrapper. Literal types and an error type are internal.

## Source type syntax

<a id="SYN-TYPE-SYNTAX"></a>
### Type syntax

```ebnf
type    = baseType { "*" | "(" [ typeArg { "," typeArg } [ "," ] ] ")" } ;
typeArg = [ "mut" ] type ;
baseType = "int" | "bool" | "void" ;
```

Examples:

```kovy
int i
bool flag
void result
int* p
int** pp
int(bool) predicate
int(mut int, int) mutate
int(bool)* functionPointer
```

A `mut` after a declaration type is not part of the type expression; it marks
the symbol as mutable:

```kovy
int mut x = 1
int* mut p = alloc 1 of int
```

`mut` before a type is only used inside function type argument lists:
`int(mut int)`.

## Primitive types

<a id="SEM-TYPE-INT"></a>
### `int`

<a id="SEM-TYPE-BOOL"></a>
### `bool`

<a id="SEM-TYPE-VOID"></a>
### `void`

- `int` is the only integer type. Arithmetic and comparisons operate on
  `int`; literals are converted to `int` when required.
- `bool` has literals `true` and `false` and the operators `not`, `and`, `or`,
  `==`, and `!=`.
- `void` is a function return type and may appear in function types. It has no
  value. A void function call is an expression of type `void` that may appear
  as an expression statement.
- The parser and sema accept a variable declared with type `void`; no value
  can initialize it, and generated Nim may reject it later. This is a current
  gap, not a supported value type.

## Internal type kinds

<a id="SEM-TYPE-INTERNAL"></a>
### Literal, mutable, error

The internal `TypeKind` enum is documented in
[INT-TYPES-KINDS](../internals/types.md#INT-TYPES-KINDS). The important parts:

- `typeNumberLit` is the type of an integer literal before a concrete type is
  required.
- `typeBoolLit` is the type of `true`/`false` before a concrete type is
  required.
- `typeMutable` wraps a type when a symbol is declared `mut`, a parameter is
  declared `mut`, or a function returns a mutable value.
- `typeError` is a recovery type produced after a failed check. It suppresses
  cascading errors in many places.

## Type compatibility

<a id="SEM-TYPE-FITS"></a>
### `fits`

`fits(actual, expected)` is the general assignment/return check:

1. If either type is `typeError`, the result is `true`.
2. `typeMutable` is stripped from the actual type and separately from the
   expected type.
3. If either type is a function or pointer, the result is `sameType` on the
   two types after stripping.
4. Otherwise, the result is membership in this table:

| Actual | Fits into |
|---|---|
| number literal | number literal, `int` |
| `int` | `int` |
| bool literal | bool literal, `bool` |
| `bool` | `bool` |
| anything else | nothing |

`void` does not fit `void` through this table; the return checker handles
void functions before reaching `fits`.

## Conversion cost

<a id="SEM-TYPE-CONVERSION-COST"></a>
### `conversionCost`

Overload resolution uses a numeric cost:

- `-1`: cannot convert.
- `0`: exact type match.
- `1`: accepted by `fits` (for example, number literal to `int`).
- Mutable actual to non-mutable expected: inner cost plus `1`.
- Expected mutable requires actual mutable; otherwise `-1`.

Examples:

| Actual | Expected | Cost |
|---|---|---|
| `int` | `int` | 0 |
| number literal | `int` | 1 |
| mutable `int` | `int` | 1 |
| mutable `int` | mutable `int` | 0 |
| `int` | mutable `int` | -1 |
| `bool` | `int` | -1 |

## `sameType`

<a id="SEM-TYPE-SAME"></a>
`sameType(a, b)` compares the kind, name, arguments, function return type, and
function argument types recursively. It does **not** consider a mutable type
equal to its inner type. Pointers are equal only when their pointee types are
equal. There are no implicit pointer conversions.

## Type strings in diagnostics

<a id="SEM-TYPE-STRINGS"></a>
`Type.toStr` produces strings such as:

- `int`, `bool`, `void`
- `int*`, `int**`
- `int(bool)`, `int(mut int, int)`
- `mutable[int]` for the internal mutable wrapper when printed through
  `Type.toStr`

Sema diagnostics often use `diagnosticTypeStr`, which prints a mutable wrapper
as `mut int` instead. Error pages record the exact message shape where it
matters.

## Literal typing

<a id="SEM-TYPE-LITERALS"></a>
- A declaration or return supplies an expected concrete type; a literal is
  checked against it with `fits`.
- Binary arithmetic produces `int`; comparison and boolean operators produce
  `bool`. The result of `1 + 2` is already `int`, not a literal type.
- An array literal infers its element type from the first element. A literal
  first element is converted to `int` or `bool`; a mutable element is read as
  its inner type.
- The unary `+` and `-` operators on a number literal produce `int`.

## Pointer and function types

<a id="SEM-TYPE-PTR"></a>
### Pointer types

`T*` is a pointer to `T`. Pointers may nest. Pointer equality is exact.
There is no implicit conversion from `int*` to `void*`, and `void*` is not a
concrete Nim type; it reaches `ERR-errNonConcreteType` in nimgen if sema
passes.

<a id="SEM-TYPE-FUNC"></a>
### Function types

`R(A, B)` is a function type returning `R` with argument types `A` and `B`.
A mutable parameter type is written `mut T` inside the type list. Function
types have no parameter names and no default values. A function value is a
closure in generated Nim; see [functions](functions.md#KOVY-FUNCTIONS).

## No implicit conversions

<a id="SEM-TYPE-NO-IMPLICIT"></a>
There is no general casting operator and no implicit conversion between
`int` and `bool`, between different pointer types, or between different
function signatures. Only literal-to-concrete and mutable-to-immutable
conversions are recognized by `fits`/`conversionCost`.

## Related pages

- [Declarations](declarations.md#KOVY-DECLARATIONS)
- [Expressions](expressions.md#KOVY-EXPRESSIONS)
- [Mutability](mutability.md#KOVY-MUTABILITY)
- [Pointers](pointers.md#KOVY-POINTERS)
- [Type compatibility table](../reference/type-compatibility.md#REF-TYPE-COMPAT)
- [Error catalogue](../errors/index.md#KOVY-ERRORS-INDEX)