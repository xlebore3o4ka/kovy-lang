# ERR-errAllocInLoop

<!-- doc-id: ERR-errAllocInLoop -->
<!-- kind: errAllocInLoop -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errAllocInLoop"></a>
## Message

Locale key: `errAllocInLoop`.

```text
Cannot allocate memory inside a loop
  Allocate the buffer once before the loop and reuse it
```

No placeholders. The addinfo is always present.

## Emitters

- `Sema.visit(Alloc)`: `isLoopContext()` is true.
- `Sema.visit(ArrayLit)`: `isLoopContext()` is true.

`isLoopContext` scans the context stack from innermost outward. It returns
true at the first `loop` and false at the first `func`. Therefore allocations
in a branch inside a loop are rejected, while allocations in a nested function
declared inside a loop are allowed.

Both visitors still validate the count, element type, and elements; they then
return `typeError`. Additional diagnostics such as `ERR-errAllocCount`,
`ERR-errAllocVoid`, or `ERR-errArrayTypeRequired` can accompany this one.

## Triggers

<a id="TRG-errAllocInLoop-alloc"></a>
### TRG-errAllocInLoop-alloc

<!-- expect-errors: errAllocInLoop -->
```kovy
while true:
  int* p = alloc 1 of int
```

An allocation in the loop body.

<a id="TRG-errAllocInLoop-array-literal"></a>
### TRG-errAllocInLoop-array-literal

<!-- expect-errors: errAllocInLoop -->
```kovy
while true:
  int* p = [1]
```

An array literal allocates storage and is rejected by the same rule.

<a id="TRG-errAllocInLoop-branch"></a>
### TRG-errAllocInLoop-branch

<!-- expect-errors: errAllocInLoop -->
```kovy
while true:
  if true:
    int* p = alloc 1 of int
  break
```

The `branch` context does not interrupt loop-context lookup.

<a id="TRG-errAllocInLoop-nested-loop"></a>
### TRG-errAllocInLoop-nested-loop

<!-- expect-errors: errAllocInLoop -->
```kovy
while true:
  while true:
    int* p = alloc 1 of int
    break
  break
```

Both loops are loop contexts; the innermost one is found first.

<a id="TRG-errAllocInLoop-nested-function-allowed"></a>
### TRG-errAllocInLoop-nested-function-allowed

<!-- expect-errors: OK -->
```kovy
while true:
  void f():
    int* p = alloc 1 of int
  break
```

This is a near miss that is accepted: the function context stops the search
before the outer loop.

## Near misses

- Allocating before the loop is accepted.
- An array literal in a function declared inside a loop is accepted, for the
  same reason as the nested-function allocation.
- An allocation in a function's parameter default is not in a loop context,
  even if the function is declared inside a loop, because the parameter scope
  is pushed with `func-arguments`, not `loop`.
- `alloc` in a loop that is already rejected for another reason can produce
  both this error and the other allocation error.

## Cascades

The allocation returns `typeError`, so an enclosing declaration does not add
`errDoesNotFit`. The `Alloc` or `ArrayLit` node is still present but has an
error type. The rest of the loop body is visited normally. This is a source
rule; there is no runtime allocation-failure check.

## Tests

- `tests/tPtr.nim`: allocation in loops
- `tests/tSema.nim`: break and allocation contexts inside nested functions

## Related

- [SEM-PTR-ALLOC-MEMORY](../language/pointers.md#SEM-PTR-ALLOC-MEMORY)
- [SEM-SCOPE-CONTEXT](../language/scopes.md#SEM-SCOPE-CONTEXT)
- [SEM-FLOW-CONTEXT](../language/control-flow.md#SEM-FLOW-CONTEXT)
- [ERR-errAllocCount](errAllocCount.md#ERR-errAllocCount)
- [ERR-errArrayTypeRequired](errArrayTypeRequired.md#ERR-errArrayTypeRequired)