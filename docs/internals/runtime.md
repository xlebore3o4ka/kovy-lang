# Runtime helpers

<!-- doc-id: INT-RUNTIME -->
<!-- status: current -->

<a id="INT-RUNTIME"></a>
`src/syskovy.nim` is imported by generated Nim as `kovyRuntime`. It supplies
pointer arithmetic, stack allocation, and the array-literal macro. There is no
Kovy-visible standard library.

## Pointer arithmetic

<a id="INT-RUNTIME-PTR-ARITH"></a>
### Pointer arithmetic

Four overloads are defined:

```nim
proc `+`*[T](p: ptr T, n: int): ptr T
proc `+`*[T](n: int, p: ptr T): ptr T
proc `-`*[T](p: ptr T, n: int): ptr T
proc `-`*[T](a, b: ptr T): int
```

The first three cast the pointer to `int`, add or subtract `n * sizeof(T)`,
and cast back. The difference overload subtracts the integer addresses and
divides by `sizeof(T)` using Nim `div`.

Consequences:

- Offsets are scaled by the pointee size.
- Pointer difference returns an element count, not a byte count.
- There is no bounds check, null check, alignment check, or overflow check.
- Arithmetic on pointers to function types is accepted by the overload if Nim
  can instantiate it; sema does not reject it. The arithmetic is expressed in
  bytes of the Nim closure/pointer representation.
- The runtime does not define pointer comparison operators.

Generated Kovy `p + n`, `n + p`, `p - n`, and `p - q` rely on these overloads.

## Stack allocation

<a id="INT-RUNTIME-ALLOCA"></a>
### `kovyAlloca`

```nim
template kovyAlloca*(size: int): pointer =
  kovyAllocaC(csize_t(size))
```

`kovyAllocaC` imports the platform alloca function:

| Compiler define | Import |
|---|---|
| `vcc` | `_alloca` from `<malloc.h>` |
| `gcc` or `clang` | `__builtin_alloca` from `<alloca.h>` |
| otherwise | `alloca` from `<alloca.h>` |

The storage is stack storage for the current function invocation. It is not
heap memory and is not freed by Kovy. The compiler does not ensure that a
pointer to it stays inside the frame.

`kovyAlloca` does not zero memory. Kovy `alloc` uses it for non-function
element types, so allocated integer/bool/pointer contents are unspecified
until written. Variables themselves are initialized by generated Nim `var`.

<a id="INT-RUNTIME-ALLOCA-ZEROED"></a>
### `kovyAllocaZeroed`

```nim
template kovyAllocaZeroed*(size: int): pointer =
  block:
    let kovyZeroSize = size
    let kovyZeroPtr = kovyAlloca(kovyZeroSize)
    zeroMem(kovyZeroPtr, kovyZeroSize)
    kovyZeroPtr
```

It allocates with `kovyAlloca` and zeroes the bytes. Kovy uses it for arrays
and for `alloc` whose element type is a function type.

## Array literal helper

<a id="INT-RUNTIME-ARRAYLIT"></a>
### `kovyArrayLit`

```nim
macro kovyArrayLit*(count: static int, T: untyped,
                    values: varargs[untyped]): untyped
```

Expansion outline:

1. Allocate a zeroed `array[count, T]` with `kovyAllocaZeroed`.
2. Assign each value to its typed slot in source order.
3. Cast the array pointer to `ptr T` and yield it.

The zeroing and typed-slot assignment exist because Nim function values are
closures and ARC/ORC may inspect the previous slot value during assignment.
Passing a plain Nim array literal would not perform closure conversion for
top-level procs in the same way.

For an empty literal the macro emits no element assignments and returns a
pointer to zero-sized storage. The generated `array[0, T]` has the usual Nim
zero-length-array representation; the pointer is not guaranteed to be
dereferenceable.

## Import exclusions

<a id="INT-RUNTIME-IMPORT"></a>
### Import exclusions

Nimgen emits:

```nim
import "<path>/src/syskovy" as kovyRuntime except kovyAlloca, kovyAllocaZeroed, kovyArrayLit
```

For `kovy emit`, the import is `./syskovy` because the runtime is written next
to the generated file.

The helper calls are qualified as `kovyRuntime.<name>`. The exclusions ensure
the unqualified macro/template names are not visible at the generated program's
top level. User symbols that collide with runtime or module names are also
prefixed by `normSym`; see
[INT-NIMGEN-NAMES](nimgen.md#INT-NIMGEN-NAMES).

## Limits

<a id="INT-RUNTIME-LIMITS"></a>
- No heap allocation, `free`, reference counting API, or garbage collector
  control is exposed to Kovy.
- No runtime error mechanism, panic, bounds check, or null check exists.
- Stack exhaustion from large or repeated alloca is not detected by Kovy.
- Alloca in a loop is rejected by sema, but this is a source rule, not a
  runtime guarantee.
- The generated program is ordinary Nim; Nim runtime behaviour applies after
  Kovy's checks.

## Implementation

- `src/syskovy.nim`: all helpers
- [INT-NIMGEN-MEMORY](nimgen.md#INT-NIMGEN-MEMORY): how helpers are called
- [SEM-PTR-ALLOC-MEMORY](../language/pointers.md#SEM-PTR-ALLOC-MEMORY):
  user-facing allocation behaviour