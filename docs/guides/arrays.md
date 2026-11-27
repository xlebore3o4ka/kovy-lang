# Arrays

<!-- doc-id: KOVY-GUIDE-ARRAYS -->
<!-- status: current -->

<a id="KOVY-GUIDE-ARRAYS"></a>
Kovy has no separate array type. An array literal allocates contiguous
elements and yields a pointer to the first element. The literal's declared
type is a pointer type such as `int*`.

## Literals and inference

<!-- expect-errors: OK -->
```kovy
int* numbers = [1, 2, 3]
bool* flags = [true, false]
```

Without `of T`, the element type is inferred from the first element. A number
literal becomes `int`; a boolean literal becomes `bool`; a mutable element is
read as its inner type.

Every remaining element is checked against the inferred type. A mismatch is
`ERR-errDoesNotFit`:

<!-- expect-errors: errDoesNotFit -->
```kovy
int* bad = [1, true]
```

## Explicit element type

Add `of T` to state the element type independent of the first element.

<!-- expect-errors: OK -->
```kovy
int* numbers = [1, 2] of int
bool* flags = [true, false] of bool
```

An empty literal cannot infer anything, so it requires `of T`:

<!-- expect-errors: OK -->
```kovy
int* empty = [] of int
```

<!-- expect-errors: errArrayTypeRequired -->
```kovy
int* empty = []
```

The declared variable type does not participate in inference: `int* p = []`
still fails, because the literal itself has no element to inspect.

## Reading and writing elements

An array value is a pointer, so element access uses pointer arithmetic and
dereference.

<!-- expect-errors: OK -->
```kovy
int* mut numbers = [10, 20, 30]
#numbers = 11
#(numbers + 1) = 21
int first = #numbers
int second = #(numbers + 1)
```

The pointer symbol must be mutable to write through the array. An immutable
`int*` can read but not assign:

<!-- expect-errors: OK -->
```kovy
int* numbers = [10, 20, 30]
int first = #numbers
```

<!-- expect-errors: errImmutableAssignment -->
```kovy
int* numbers = [10, 20, 30]
#numbers = 11
```

There is no length field and no bounds check. Store the length separately or
use a sentinel:

<!-- expect-errors: OK -->
```kovy
int* values = [3, 4, 5]
int count = 3
int mut sum = 0
int mut i = 0
while i < count:
  sum = sum + #(values + i)
  i = i + 1
```

## Nested arrays

An array of arrays is a pointer to pointers. Use an explicit `of T*` element
type when the nested literals would otherwise be ambiguous.

<!-- expect-errors: OK -->
```kovy
int** rows = [[1, 2], [3, 4]] of int*
int first = #(#rows)
int second = #(#(rows + 1) + 1)
```

`#rows` is the first `int*`; `#(#rows)` is its first `int`. The expression
`#(#(rows + 1) + 1)` selects row 1, column 1.

## Arrays of function values

A function type can be an element type.

<!-- expect-errors: OK -->
```kovy
void hello():
  int x = 1

void()* handlers = [hello] of void()
(#(handlers + 0))()
```

The element type is `void()`, a function returning `void` with no parameters.
The call needs parentheses: `(#(handlers + 0))()` dereferences the element and
then calls it.

## Allocation restriction

An array literal allocates storage, so it is rejected inside a loop body just
like `alloc`:

<!-- expect-errors: errAllocInLoop -->
```kovy
while true:
  int* p = [1, 2]
  break
```

Build the array before the loop, or inside a function declared in the loop.

## Rejected element types

`void` cannot be stored. Both an explicit `of void` and an inferred `void`
element are rejected:

<!-- expect-errors: errAllocVoid -->
```kovy
void* p = [] of void
```

See [ERR-errAllocVoid](../errors/errAllocVoid.md#ERR-errAllocVoid) and
[ERR-errArrayTypeRequired](../errors/errArrayTypeRequired.md#ERR-errArrayTypeRequired).

## Current quirks

- An array literal is not writable by itself. Bind it to a `mut` pointer
  symbol before writing.
- No length is stored and no index is checked. The programmer owns bounds and
  lifetime.
- A nested literal without `of` infers from the first inner literal; explicit
  `of T*` is clearer and avoids surprises.

## Next steps

- [Array semantics](../language/arrays.md#KOVY-ARRAYS)
- [Pointers and allocation](pointers-alloc.md#KOVY-GUIDE-POINTERS)
- [RPN interpreter](rpn.md#KOVY-GUIDE-RPN)