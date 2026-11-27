# Mutability and write permission

<!-- doc-id: KOVY-MUTABILITY -->
<!-- status: current -->

<a id="KOVY-MUTABILITY"></a>
Immutability is the default. `mut` is written after a type in declarations and
parameters, after the return type in a function declaration, and before a
function type argument type.

## Syntax

<a id="SYN-MUT"></a>
### `mut` positions

```kovy
int mut value = 1
int* mut p = alloc 1 of int
int f(int mut x):
  x = x + 1
  return x
int mut g():
  return value
int(mut int) cb
```

In order, these are: a mutable variable, a mutable pointer variable, a
function with a mutable parameter, a function with a mutable return type, and
a function type with a mutable argument type.

`mut` is not a prefix on a declaration: `mut int x` is not a declaration
form. Inside function type argument lists it is a prefix: `int(mut int)`.

## Internal representation

<a id="SEM-MUT-TYPE"></a>
### Mutable type wrapper

Sema represents mutability as `typeMutable` around an inner type. A mutable
symbol has a mutable type. The wrapper is stripped by `fits` for assignment
compatibility, but exact checks such as `sameType` distinguish it.

The wrapper is not a general qualifier on pointee memory. It describes the
storage/permission of the symbol or expression. For example, `int* mut p`
means the pointer variable `p` is mutable; it does not by itself describe the
mutability of `*p`. Dereference write permission is computed separately.

## Write permission (`grantsWrite`)

<a id="SEM-MUT-WRITE"></a>
### Expression write permission

Sema annotates each expression with `grantsWrite`. The rules are:

| Expression | `grantsWrite` |
|---|---|
| mutable symbol | true |
| immutable symbol | false |
| assignment expression | left side's `grantsWrite` |
| pointer `+`/`-` with an integer | pointer operand's `grantsWrite` |
| pointer difference (`ptr - ptr`) | false (result is `int`) |
| dereference `#x` | `x.grantsWrite` |
| address-of `addr x` | false; the resulting pointer is not writable by itself |
| `alloc ...` | false |
| array literal | false |
| call | true only when the function return type is mutable |
| number, bool, other unary/binary | false |

A write through a pointer requires the dereferenced expression to have a
mutable type. Because `#x` is mutable only when `x.grantsWrite` is true, an
immutable pointer symbol cannot write:

<!-- expect-errors: errImmutableAssignment -->
```kovy
int* p = alloc 1 of int
#p = 5
```

Binding the same allocation to a mutable pointer makes the write legal:

<!-- expect-errors: OK -->
```kovy
int* mut p = alloc 1 of int
#p = 5
```

`addr` deliberately does not create write permission:

<!-- expect-errors: errImmutableAssignment -->
```kovy
int mut x = 1
int* p = addr x
#p = 5
```

The pointer must be bound to a mutable symbol:

<!-- expect-errors: OK -->
```kovy
int mut x = 1
int* mut p = addr x
#p = 5
```

## Assignment to symbols

<a id="SEM-MUT-ASSIGN"></a>
### Symbol assignment

The left side of `=` must have a mutable type. It is not enough that the value
came from a mutable source; the lvalue expression itself must ask for write
permission.

```kovy
int x = 1
x = 2
```

The second assignment is rejected with `ERR-errImmutableAssignment`.

```kovy
int mut y = 1
y = 2
```

This assignment is accepted.

Assignment to a dereference is checked through `grantsWrite`. Assignment to
`addr`, `alloc`, an array literal, or a non-mutable call result is rejected.

## Mutable returns

<a id="SEM-MUT-RETURN"></a>
### Mutable-returning functions

`int mut f()` returns a mutable `int`; `int* mut f()` returns a mutable
pointer. A call to such a function has `grantsWrite = true`, so its result can
be written through or used where a mutable value is required.

```kovy
int* mut pick(int* mut p):
  return p

int use(int* mut p):
  #pick(p) = 5
  return 0
```

The return checker has one lifetime-specific rule:
`ERR-errReturnDanglingMutable` fires when a mutable-returning function returns
a mutable symbol whose declaration scope is deeper than the function's
parameter scope. This catches a local mutable value escaping through a
mutable return, but not general pointer escapes.

```kovy
int mut f():
  int mut x = 1
  return x
```

The return is rejected with `ERR-errReturnDanglingMutable`.

Returning a mutable parameter or a mutable global is allowed:

```kovy
int mut global = 1

int mut fromGlobal():
  return global

int mut fromParam(int mut x):
  return x
```

## Pointers and memory

<a id="SEM-MUT-PTR"></a>
### Pointers

- `int*` is a pointer value. `int* mut p` is a mutable pointer variable.
- `alloc` returns a pointer but does not grant write access.
- `#p` grants write access only through a mutable pointer symbol or a mutable
  return value.
- `addr x` requires `x` to be mutable, but the resulting pointer does not
  grant write access until stored in a mutable pointer symbol.
- Pointer arithmetic preserves write permission from the pointer operand.
- Pointer difference returns `int` and therefore has no write permission.
- `alloc` and array literal writes are controlled by their binding symbol, not
  by the allocation expression itself.

## Current lifetime limitation

<a id="SEM-MUT-LIFETIME-LIMIT"></a>
Mutability checking is not lifetime checking. The current compiler accepts
many programs where a pointer to local stack storage escapes through return,
assignment to a global, or a function argument. The only lifetime-related
diagnostic is the narrow mutable-return rule above. Documented examples of
accepted unsafe programs are in
[pointers](pointers.md#SEM-PTR-LIFETIME).

## Examples

<a id="EX-MUT-BASIC"></a>
<!-- expect-errors: OK -->
```kovy
int mut x = 1
x = 2
int* mut p = addr x
#p = 3
```

<a id="EX-MUT-IMMUTABLE"></a>
<!-- expect-errors: errImmutableAssignment -->
```kovy
int x = 1
x = 2
```

<a id="EX-MUT-ADDR"></a>
<!-- expect-errors: errImmutableAssignment -->
```kovy
int mut x = 1
int* p = addr x
#p = 2
```

## Diagnostics

- [ERR-errImmutableAssignment](../errors/errImmutableAssignment.md#ERR-errImmutableAssignment)
- [ERR-errAddrFromImmutable](../errors/errAddrFromImmutable.md#ERR-errAddrFromImmutable)
- [ERR-errImmutableReturn](../errors/errImmutableReturn.md#ERR-errImmutableReturn)
- [ERR-errReturnDanglingMutable](../errors/errReturnDanglingMutable.md#ERR-errReturnDanglingMutable)
- [ERR-errDerefNonPointer](../errors/errDerefNonPointer.md#ERR-errDerefNonPointer)

## Tests

- `tests/tPtr.nim`: write permission, addr, mutable returns, pointer arithmetic
- `tests/tFunc.nim`: mutable parameters and function types
- `tests/tSema.nim`: mutable element reads