# Array literals

<!-- doc-id: KOVY-ARRAYS -->
<!-- status: current -->

<a id="KOVY-ARRAYS"></a>
Kovy has no array value type and no indexing syntax. An array literal allocates
stack storage and produces a pointer to its first element.

## Syntax

<a id="SYN-ARRAY-LITERAL"></a>
### Literal form

```ebnf
arrayLiteral = "[" [ expression { "," expression } [ "," ] ] "]"
               [ "of" type ] ;
```

```kovy
int* a = [1, 2, 3]
int* b = [1, 2, 3] of int
int* c = [] of int
```

- Elements are separated by commas. A trailing comma is accepted.
- An empty literal requires `of T`; otherwise the element type cannot be
  inferred.
- `of T` is optional for a non-empty literal.
- The result type is `T*`, where `T` is the inferred or explicit element type.
- There is no `.len`, `[i]`, slice, or array comparison operator. Use pointer
  arithmetic and `#`:

```kovy
int* a = [10, 20, 30]
int second = #(a + 1)
```

## Element type inference

<a id="SEM-ARR-INFERENCE"></a>
### Inference

Without `of T`:

1. The first element's type is visited.
2. A mutable type is stripped to its inner type.
3. A number literal becomes `int`; a bool literal becomes `bool`.
4. A `void` first element is `ERR-errAllocVoid`.
5. The resulting type becomes the array element type.
6. Every remaining element is checked with `fits(element, elemType)`.
   A mismatch is `ERR-errDoesNotFit`.

```kovy
int* a = [1, 2, 3]
bool* b = [true, false]
int mut x = 1
int* c = [x]
```

The first array has inferred `int` elements, the second `bool` elements, and
the third reads a mutable `x` as its inner type.

With explicit `of T`, the declared element type is used for all elements. A
void element type is `ERR-errAllocVoid`.

If the first element itself has an error type, sema returns immediately and
does not add further element errors.

## Memory

<a id="SEM-ARR-MEMORY"></a>
### Storage

Array literals use `kovyAllocaZeroed` through the `kovyArrayLit` macro in
`src/syskovy.nim`. The storage is zeroed, elements are assigned in source
order, and the result is cast to a pointer to the element type.

Consequences:

- The storage is stack storage in generated Nim.
- It is not a heap allocation and is never freed.
- It is rejected inside a loop, exactly like `alloc`.
- A nested function declared inside a loop resets the loop context, so an
  array literal inside that nested function is allowed.
- The array literal expression itself does not grant write permission.
- Binding the result to a mutable pointer is required for element writes:
  `int* mut p = [1, 2]` and then `#p = 3`.

Returning the pointer is currently accepted even though the storage belongs to
the returning function's stack frame. See
[SEM-PTR-LIFETIME](pointers.md#SEM-PTR-LIFETIME).

## Nested literals

<a id="SEM-ARR-NESTED"></a>
### Nested literals

Array literals may contain array literals. The inner literal's type is a
pointer, so the outer element type is that pointer type:

```kovy
int* row0 = [1, 2]
int* row1 = [3, 4]
int** rows = [row0, row1]
```

An inline nesting such as `[[1, 2], [3, 4]]` is parsed and type-checked the
same way; each inner allocation is performed before the outer allocation is
filled.

## Function values

<a id="SEM-ARR-FUNCTIONS"></a>
### Arrays of functions

Function values can be elements:

```kovy
void hello():
  int x = 1

void()* handlers = [hello]
(#(handlers + 0))()
```

The generated array-literal helper assigns each element through a typed slot.
This matters for Nim closure conversion; a plain Nim array literal is not used
for function elements.

## Restrictions

<a id="SEM-ARR-RULES"></a>
- Empty without `of T`: `ERR-errArrayTypeRequired`.
- `void` element type: `ERR-errAllocVoid`.
- Element mismatch: `ERR-errDoesNotFit`.
- Literal inside a loop: `ERR-errAllocInLoop`; an empty literal in a loop can
  also produce `ERR-errArrayTypeRequired`.
- No array length or bounds check.
- No array value assignment, copying, or comparison.
- No `array` keyword or array type syntax.
- No heap array; there is no `new[]`.

## Examples

<a id="EX-ARR-BASIC"></a>
<!-- expect-errors: OK -->
```kovy
int* a = [1, 2, 3]
int* b = [] of int
bool* c = [true, false] of bool
int x = #(a + 1)
```

<a id="EX-ARR-MUTABLE"></a>
<!-- expect-errors: OK -->
```kovy
int* mut p = [1, 2, 3]
#p = 10
#(p + 1) = 20
```

<a id="EX-ARR-EMPTY"></a>
<!-- expect-errors: errArrayTypeRequired -->
```kovy
int* p = []
```

<a id="EX-ARR-LOOP"></a>
<!-- expect-errors: errAllocInLoop -->
```kovy
int mut i = 0
while i < 3:
  int* p = [1, 2]
  i = i + 1
```

<a id="EX-ARR-MISMATCH"></a>
<!-- expect-errors: errDoesNotFit -->
```kovy
int* p = [1, true]
```

## Diagnostics

- [ERR-errArrayTypeRequired](../errors/errArrayTypeRequired.md#ERR-errArrayTypeRequired)
- [ERR-errAllocVoid](../errors/errAllocVoid.md#ERR-errAllocVoid)
- [ERR-errAllocInLoop](../errors/errAllocInLoop.md#ERR-errAllocInLoop)
- [ERR-errDoesNotFit](../errors/errDoesNotFit.md#ERR-errDoesNotFit)
- [ERR-errImmutableAssignment](../errors/errImmutableAssignment.md#ERR-errImmutableAssignment)

## Tests

- `tests/tSema.nim`: inference, explicit type, empty literal, mismatch, loop
  context, mutable elements
- `tests/tPtr.nim`: allocation, nested literals, function elements, writes
  through elements