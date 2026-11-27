# Type model internals

<!-- doc-id: INT-TYPES -->
<!-- status: current -->

<a id="INT-TYPES"></a>
Types are a value object declared in `src/types.nim`:

```nim
Type = object
  name: string
  args: seq[Type]
  case kind: TypeKind
  of typeFunc:
    funcReturnType: ref Type
    funcArgTypes: seq[Type]
  else: discard
```

`funcReturnType` is a `ref Type` so a function type can be recursive in
principle; the parser does not construct recursive source types.

## Kinds

<a id="INT-TYPES-KINDS"></a>
### `TypeKind`

| Kind | Constructor | `name` | `args` | `toStr` |
|---|---|---|---|---|
| `typeNumberLit` | `newNumberLitType` | `numberLiteral` | empty | `numberLiteral` |
| `typeBoolLit` | `newBoolLitType` | `boolLiteral` | empty | `boolLiteral` |
| `typeInt` | `newIntType` | `int` | empty | `int` |
| `typeBool` | `newBoolType` | `bool` | empty | `bool` |
| `typeVoid` | `newVoidType` | `void` | empty | `void` |
| `typeError` | `newErrorType` | `error` | empty | `error` |
| `typeMutable` | `newMutableType(t)` | `mutable` | `[t]` | `mutable[t]` |
| `typePtr` | `newPtrType(t)` | `ptr` | `[t]` | `t*` |
| `typeFunc` | `newFuncType(ret, args)` | `func` | empty | `ret(arg, ...)` |

`typeMutable` is used for mutable symbols, mutable parameters, mutable return
types, and mutable dereference results. It is not a general type qualifier on
pointee memory.

`typeError` is a recovery value. `fits` and `conversionCost` treat it as
compatible with everything; many sema procedures stop after receiving it.
`sameType` does **not** treat it specially: `typeError` equals only
`typeError`.

## Constructors

<a id="INT-TYPES-CONSTRUCTORS"></a>
### Constructors

- `newNumberLitType()` and `newBoolLitType()` are the types of literals before
  conversion.
- `newIntType()`, `newBoolType()`, `newVoidType()`, and `newErrorType()`
  return scalar kinds.
- `newMutableType(t)` wraps `t` in `args[0]`.
- `newPtrType(t)` wraps `t` in `args[0]`.
- `newFuncType(returnType, argTypes)` stores a deep copied return type under
  `funcReturnType` and the argument list under `funcArgTypes`. `args` is
  empty for function types.

## String form

<a id="INT-TYPES-TOSTR"></a>
### `toStr`

The function type branch prints:

```text
<return>[<args>](<function parameters>)
```

`args` is empty for parser-produced function types, so the bracketed part is
normally absent. If a function type had both `args` and `funcArgTypes`, the
bracket part would appear even though it has no source syntax.

Function parameter types print `mut T` when the argument type is
`typeMutable`. All other kinds with one argument print `name[arg]`; pointer
types are special-cased before that and print `T*`.

Examples:

| Type | `toStr` |
|---|---|
| `newMutableType(newIntType())` | `mutable[int]` |
| `newPtrType(newIntType())` | `int*` |
| `newFuncType(newVoidType(), @[])` | `void()` |
| `newFuncType(newIntType(), @[newMutableType(newIntType())])` | `int(mut int)` |

Sema diagnostics usually use `diagnosticTypeStr`, which prints the mutable
wrapper as `mut T` instead of `mutable[T]`.

## Equality and hashing

<a id="INT-TYPES-EQUALITY"></a>
### `sameType` and `hash`

`sameType(a, b)`:

1. Requires equal `kind`.
2. For function types, requires equal argument count, equal return type, and
   pairwise equal argument types.
3. Otherwise requires equal `name`.
4. Requires equal `args` length and pairwise equal arguments.

It does not normalize mutable types, does not erase literal types, and does not
coerce pointers. `int` and `numberLiteral` are different types even though a
number literal fits `int`.

`hash` includes the kind, then the name for non-function kinds, then all
`args`. For function types it includes the return type and argument types
instead of the name. Equal types hash equally.

## Compatibility

<a id="INT-TYPES-FITS"></a>
### `fits`

`fits(actual, expected)` is defined in sema:

1. Either side `typeError` -> true.
2. Strip `typeMutable` from the actual side.
3. Strip `typeMutable` from the expected side.
4. If either side is `typeFunc` or `typePtr`, return `sameType`.
5. Otherwise consult:

| Actual | Expected |
|---|---|
| `typeNumberLit` | `typeNumberLit`, `typeInt` |
| `typeInt` | `typeInt` |
| `typeBoolLit` | `typeBoolLit`, `typeBool` |
| `typeBool` | `typeBool` |

`typeVoid` matches nothing through this table. Void return compatibility is
handled by the return checker before `fits`.

## Conversion cost

<a id="INT-TYPES-COST"></a>
### `conversionCost`

- Either side `typeError` -> 0.
- Expected mutable: actual must be mutable; recurse inside.
- Actual mutable: recurse inside and add 1 if it succeeds.
- `sameType` -> 0.
- `fits` -> 1.
- Otherwise -> -1.

A literal-to-concrete conversion costs 1. A mutable-to-immutable conversion
costs 1 plus any inner conversion. Immutable-to-mutable is -1. Function
pointers and function types use exact `sameType`.

## Coverage links

- User-facing type rules: [KOVY-TYPES](../language/types.md#KOVY-TYPES)
- `fits` table: [SEM-TYPE-FITS](../language/types.md#SEM-TYPE-FITS)
- Cost table: [SEM-TYPE-CONVERSION-COST](../language/types.md#SEM-TYPE-CONVERSION-COST)
- Compatibility reference: [REF-TYPE-COMPAT](../reference/type-compatibility.md#REF-TYPE-COMPAT)