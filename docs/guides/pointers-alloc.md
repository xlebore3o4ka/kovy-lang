# Pointers and allocation

<!-- doc-id: KOVY-GUIDE-POINTERS -->
<!-- status: current -->

<a id="KOVY-GUIDE-POINTERS"></a>
A pointer is written with a postfix `*`: `int*` is a pointer to `int`, and
`int**` is a pointer to `int*`. Allocation is explicit with `alloc`.
Dereference is `#`; there are no comments.

## Allocation

<!-- expect-errors: OK -->
```kovy
int* p = alloc 4 of int
```

`alloc n of T` allocates `n` elements of type `T` and yields `T*`. The short
form `alloc T` allocates one element:

<!-- expect-errors: OK -->
```kovy
int* mut p = alloc int
#p = 7
int value = #p
```

The count is an `int` expression. It is parsed with full expression
precedence, so `alloc n + 1 of int` means `alloc (n + 1) of int`:

<!-- expect-errors: OK -->
```kovy
int n = 2
int* p = alloc n + 1 of int
```

Allocation is rejected inside a loop body. Allocate once before the loop and
reuse the buffer:

<!-- expect-errors: OK -->
```kovy
int* mut buffer = alloc 8 of int
int mut i = 0
while i < 8:
  #(buffer + i) = i
  i = i + 1
```

<!-- expect-errors: errAllocInLoop -->
```kovy
while true:
  int* p = alloc 1 of int
  break
```

A function declared inside a loop is a separate execution context, so an
allocation in that function's body is allowed. See
[ERR-errAllocInLoop](../errors/errAllocInLoop.md#ERR-errAllocInLoop).

## Dereference

`#p` reads the element `p` points to. `#(p + i)` reads element `i`.

<!-- expect-errors: OK -->
```kovy
int* mut p = alloc 2 of int
#p = 10
#(p + 1) = 20
int first = #p
int second = #(p + 1)
```

`#` binds to a postfix call less tightly than the call itself. `#p()` parses
as `#(p())`: call `p`, then dereference the result. To call through a function
pointer, write `(#p)()`.

Dereferencing a non-pointer is rejected:

<!-- expect-errors: errDerefNonPointer -->
```kovy
int x = 1
int y = #x
```

## Address of a value

`addr x` requires a mutable expression and yields a pointer to its type.

<!-- expect-errors: OK -->
```kovy
int mut value = 7
int* p = addr value
int copy = #p
```

Taking an address does not grant write permission. Bind the pointer to a
mutable pointer symbol before writing:

<!-- expect-errors: OK -->
```kovy
int mut value = 7
int* mut p = addr value
#p = 9
```

<!-- expect-errors: errAddrFromImmutable -->
```kovy
int value = 7
int* p = addr value
```

## Writing through pointers

Write permission is a property of the expression, not of the memory. A
mutable pointer symbol grants it; an immutable pointer symbol does not.

<!-- expect-errors: OK -->
```kovy
int* mut p = alloc 1 of int
#p = 5
```

<!-- expect-errors: errImmutableAssignment -->
```kovy
int* p = alloc 1 of int
#p = 5
```

A mutable parameter and a mutable return value also grant write permission:

<!-- expect-errors: OK -->
```kovy
void set(int* mut p, int value):
  #p = value

int* mut identity(int* mut p):
  return p

int* mut q = alloc 1 of int
set(q, 3)
#identity(q) = 4
```

## Pointer arithmetic

`ptr + int`, `int + ptr`, `ptr - int`, and `ptr - ptr` are defined when the
pointee types match. Pointer plus pointer and pointer comparison are rejected.

<!-- expect-errors: OK -->
```kovy
int* advance(int* p, int n):
  return p + n

int distance(int* a, int* b):
  return a - b
```

Write permission follows pointer arithmetic when it comes from a mutable
pointer:

<!-- expect-errors: OK -->
```kovy
int* mut p = alloc 3 of int
#(p + 1) = 2
#(1 + p) = 3
#(p - 1) = 4
```

## Function pointers

A pointer to a function type is allocated like any other pointer.

<!-- expect-errors: OK -->
```kovy
void hello():
  int x = 1

void()* mut dispatch = alloc 1 of void()
#dispatch = hello
(#dispatch)()
```

`void()` is a function type returning `void` with no parameters. The
parentheses around `#dispatch` are required: `#dispatch()` means
`#(dispatch())`, which calls `dispatch` first.

## `void*` is not concrete

Sema accepts `void*`, but nimgen rejects it because Nim has no concrete
`void` value type:

<!-- expect-errors: errNonConcreteType -->
```kovy
void* p
```

`alloc 1 of void` is rejected earlier, by sema, as `ERR-errAllocVoid`.

## Lifetime caveat

The current compiler only rejects returning a mutable local symbol directly.
It does **not** reject returning a pointer or an address of a local:

<!-- expect-errors: OK -->
```kovy
int* f():
  int mut x = 1
  return addr x
```

This is accepted today and is a current lifetime hole, not a guarantee. Do not
rely on such a pointer after the function returns. See
[SEM-PTR-LIFETIME](../language/pointers.md#SEM-PTR-LIFETIME).

## Next steps

- [Pointer semantics](../language/pointers.md#KOVY-POINTERS)
- [Mutability](../language/mutability.md#KOVY-MUTABILITY)
- [Arrays](arrays.md#KOVY-GUIDE-ARRAYS)