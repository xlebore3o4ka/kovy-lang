# Pointers and allocation

<!-- doc-id: KOVY-POINTERS -->
<!-- status: current -->

<a id="KOVY-POINTERS"></a>
Kovy has C-like pointer syntax and stack allocation. Memory is not a managed
heap: `alloc` and array literals use `alloca`-style storage in generated Nim.

## Pointer type syntax

<a id="SYN-PTR-TYPE"></a>
### Pointer types

```ebnf
type = baseType { "*" | "(" ... ")" } ;
```

```kovy
int* p
int** pp
int(bool)* functionPointer
void()* dispatch
```

`T*` points to `T`. Pointer suffixes repeat. `void*` is syntactically valid
but is not a concrete Nim type; it reaches `ERR-errNonConcreteType` during
nimgen if sema accepts the surrounding program.

Pointer types are compared exactly by `sameType`. There is no implicit
conversion between `int*` and `bool*`, or between `T*` and `void*`.

## `alloc`

<a id="SYN-ALLOC"></a>
### Allocation forms

```ebnf
allocExpr = "alloc" type
          | "alloc" expression "of" type ;
```

```kovy
int* one = alloc int
int* many = alloc 4 of int
int** pointers = alloc 2 of int*
```

- The short form is parsed only when the next token is a type keyword (`int`,
  `bool`, `void`). It allocates one element.
- `alloc n of T` evaluates `n` and allocates `n` elements of `T`.
- The count must fit `int` (`ERR-errAllocCount`).
- The element type must not be `void` (`ERR-errAllocVoid`).
- Allocation is rejected inside a loop (`ERR-errAllocInLoop`). A branch does
  not leave a loop context; a nested function does.
- The result type is `T*`.
- The result does not grant write permission by itself.

<a id="SEM-PTR-ALLOC-MEMORY"></a>
### Allocation storage

Generated code calls `kovyRuntime.kovyAlloca((count) * sizeof(T))` and casts
the result to `ptr T`. Allocation is not zeroed in general. If `T` is a
function type, `kovyAllocaZeroed` is used because generated Nim closures are
touched during assignment and uninitialized function slots would be unsafe.

There is no `free`, `new`, or heap API. The storage lifetime is the enclosing
stack frame in the generated Nim program. Returning a pointer to such storage
is currently accepted by sema in most cases; see
[SEM-PTR-LIFETIME](#SEM-PTR-LIFETIME).

A global `alloc` is emitted at its source position in the generated top-level
block. It is still an `alloca`-style request, not a heap allocation; do not
interpret it as program-lifetime memory merely because the Kovy declaration is
global.

## Dereference

<a id="SYN-PTR-DEREF"></a>
### `#expr`

`#` is a unary operator:

```kovy
int* mut p = alloc 1 of int
#p = 5
int x = #p
int** pp = addr p
int y = ##pp
```

Semantics:

- The operand is checked after stripping a mutable wrapper. It must be a
  pointer (`ERR-errDerefNonPointer`).
- The result is the pointee type.
- If the operand expression has `grantsWrite = true`, the result has a mutable
  type and can be assigned. Otherwise the result is immutable.
- Double dereference is written `##pp`.
- `#p()` parses as `#(p())` because postfix call binds tighter. Use `(#p)()`
  to call through a function pointer.

<a id="SEM-PTR-DEREF-GRANT"></a>
### Write permission through dereference

`#p` is writable only when `p` is a mutable pointer expression. `alloc` and
`addr` do not create write permission themselves.

<!-- expect-errors: errImmutableAssignment -->
```kovy
int* p = alloc 1 of int
#p = 5
```

<!-- expect-errors: OK -->
```kovy
int* mut q = alloc 1 of int
#q = 5
```

See [mutability](mutability.md#SEM-MUT-WRITE) for the complete
`grantsWrite` table.

## Address-of

<a id="SYN-PTR-ADDR"></a>
### `addr expr`

`addr expr` requires `expr` to have a mutable type. It returns a pointer to
the expression's type.

```kovy
int mut x = 1
int* p = addr x
int* mut q = addr x
int* fromDeref = addr #q
```

- `addr` of an immutable symbol, immutable dereference, `alloc`, array
  literal, or immutable call result is `ERR-errAddrFromImmutable`.
- The result pointer does **not** grant write permission. Bind it to a mutable
  pointer symbol to write through it.
- `addr` of a mutable-returning function call is accepted.
- `addr` of a dereference requires the dereferenced expression to be mutable:
  `addr #p` is rejected when `p` is immutable.

## Pointer arithmetic

<a id="SEM-PTR-ARITHMETIC"></a>
### Arithmetic

The following forms are accepted:

| Form | Result |
|---|---|
| `p + n` | same pointer type; `n` must fit `int` |
| `n + p` | same pointer type; `n` must fit `int` |
| `p - n` | same pointer type; `n` must fit `int` |
| `p - q` | `int`; both pointers must have the same type |

- `p + n` and `n + p` preserve `p`'s write permission.
- `p - n` preserves `p`'s write permission.
- `p - q` returns `int` and has no write permission.
- `int - ptr`, `ptr + ptr`, pointer comparisons, and pointer arithmetic with
  non-integer operands are `ERR-errBinaryMismatch`.
- The generated runtime scales offsets by `sizeof(T)`; see
  [INT-RUNTIME-PTR-ARITH](../internals/runtime.md#INT-RUNTIME-PTR-ARITH).

## Function pointers

<a id="SEM-PTR-FUNCTION"></a>
### Function pointers

A pointer to a function type is written `ReturnType(ArgTypes)*`:

```kovy
void hello():
  int x = 1

void()* mut dispatch = alloc 1 of void()
#dispatch = hello
(#dispatch)()
```

`dispatch` has pointer type. `dispatch()` is not callable; dereference first.
`#dispatch()` means `#(dispatch())`, which is not the intended call. Parenthesize
the dereference: `(#dispatch)()`.

## Lifetime and aliasing

<a id="SEM-PTR-LIFETIME"></a>
### Current lifetime behavior

The compiler currently accepts all of the following programs even though the
pointer can outlive its storage:

```kovy
int* returnLocal():
  int* p = alloc 1 of int
  return p

int* returnArray():
  return [1, 2]

int* returnAddress():
  int mut x = 1
  return addr x
```

It also accepts storing a local pointer into a global or passing it to a
function that may store it. The only lifetime-specific diagnostic is
`errReturnDanglingMutable` for mutable-returning functions; it does not cover
ordinary pointer returns, `addr`, array literals, globals, or arguments.

These are current limitations. They are not evidence of a borrow checker.

## Other current rules

<a id="SEM-PTR-RULES"></a>
- There is no null pointer literal, pointer comparison, bounds checking, or
  pointer-to-integer cast syntax.
- A `void*` value is not concrete for code generation; see
  [ERR-errNonConcreteType](../errors/errNonConcreteType.md#ERR-errNonConcreteType).
- Allocation inside a loop is rejected even when the allocation is conditional.
- Allocation in a nested function declared inside a loop is allowed.
- Pointer arithmetic on function pointers passes sema as ordinary pointer
  arithmetic; the generated Nim may reject it later.
- Pointer values are not automatically initialized. Uninitialized pointer
  variables are zero-initialized by generated Nim `var`, but the pointed-to
  allocation contents are not zeroed unless the element type is a function.

## Examples

<a id="EX-PTR-ALLOC-BASIC"></a>
<!-- expect-errors: OK -->
```kovy
int* mut p = alloc 2 of int
#p = 10
#(p + 1) = 20
int x = #(p + 1)
```

<a id="EX-PTR-READONLY"></a>
<!-- expect-errors: errImmutableAssignment -->
```kovy
int* p = alloc 1 of int
#p = 10
```

<a id="EX-PTR-ADDR-MUTABLE"></a>
<!-- expect-errors: OK -->
```kovy
int mut x = 1
int* mut p = addr x
#p = 2
```

<a id="EX-PTR-ESCAPE-ACCEPTED"></a>
<!-- expect-errors: OK -->
```kovy
int* f():
  int* p = alloc 1 of int
  return p
```

## Diagnostics

- [ERR-errAllocCount](../errors/errAllocCount.md#ERR-errAllocCount)
- [ERR-errAllocVoid](../errors/errAllocVoid.md#ERR-errAllocVoid)
- [ERR-errAllocInLoop](../errors/errAllocInLoop.md#ERR-errAllocInLoop)
- [ERR-errDerefNonPointer](../errors/errDerefNonPointer.md#ERR-errDerefNonPointer)
- [ERR-errAddrFromImmutable](../errors/errAddrFromImmutable.md#ERR-errAddrFromImmutable)
- [ERR-errImmutableAssignment](../errors/errImmutableAssignment.md#ERR-errImmutableAssignment)
- [ERR-errBinaryMismatch](../errors/errBinaryMismatch.md#ERR-errBinaryMismatch)
- [ERR-errNonConcreteType](../errors/errNonConcreteType.md#ERR-errNonConcreteType)
- [ERR-errReturnDanglingMutable](../errors/errReturnDanglingMutable.md#ERR-errReturnDanglingMutable)

## Tests

- `tests/tPtr.nim`: pointer types, alloc, dereference, write permission,
  `addr`, pointer arithmetic, function pointers, runtime names
- `tests/tSema.nim`: array literals and loop context
- `examples/rpn.kovy`: global buffers, pointer arithmetic, function pointers