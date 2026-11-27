# ERR-errAllocVoid

<!-- doc-id: ERR-errAllocVoid -->
<!-- kind: errAllocVoid -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errAllocVoid"></a>
## Message

Locale key: `errAllocVoid`.

```text
Cannot allocate elements of type void
```

No placeholders and no addinfo.

## Emitters

- `Sema.visit(Alloc)`: the requested element type is `void`.
- `Sema.visit(ArrayLit)` with an explicit `of T`: `T` is `void`.
- `Sema.visit(ArrayLit)` without an explicit type: the first element's type,
  after stripping mutable wrappers, is `void`.

Void cannot be stored, so both allocation forms reject it.

## Triggers

<a id="TRG-errAllocVoid-alloc"></a>
### TRG-errAllocVoid-alloc

<!-- expect-errors: errAllocVoid -->
```kovy
void* p = alloc 1 of void
```

The element type is `void`.

<a id="TRG-errAllocVoid-array-explicit"></a>
### TRG-errAllocVoid-array-explicit

<!-- expect-errors: errAllocVoid -->
```kovy
void* p = [1] of void
```

The explicit element type is `void`, so elements are not checked against it.

<a id="TRG-errAllocVoid-array-inferred"></a>
### TRG-errAllocVoid-array-inferred

<!-- expect-errors: errAllocVoid -->
```kovy
void v
void* p = [v]
```

The inferred element type from the first element is `void`. The diagnostic is
attached to that first element.

<a id="TRG-errAllocVoid-in-loop"></a>
### TRG-errAllocVoid-in-loop

<!-- expect-errors: errAllocInLoop, errAllocVoid -->
```kovy
while true:
  void* p = alloc 1 of void
  break
```

The loop check runs first, then the element-type check.

## Near misses

- `void* p` with no initializer is accepted by sema; code generation reports
  `ERR-errNonConcreteType`.
- `alloc 1 of void*` has element type `void*`, not `void`; sema accepts it and
  nimgen reports `ERR-errNonConcreteType` for the inner `void*`.
- A `void`-returning call used as a first array element also infers `void` and
  reaches this error.
- A non-void element type is unaffected by this check.

## Cascades

The allocation returns `typeError`, suppressing an enclosing
`errDoesNotFit`. For an explicit array element type, remaining elements are not
checked. For an inferred void element type, the first element has already been
visited. In a loop, `errAllocInLoop` may already be present.

## Tests

- `tests/tPtr.nim`: `alloc 1 of void` rejection
- `tests/tSema.nim`: array literal element handling

## Related

- [SEM-PTR-ALLOC-MEMORY](../language/pointers.md#SEM-PTR-ALLOC-MEMORY)
- [SEM-ARR-RULES](../language/arrays.md#SEM-ARR-RULES)
- [ERR-errAllocCount](errAllocCount.md#ERR-errAllocCount)
- [ERR-errNonConcreteType](errNonConcreteType.md#ERR-errNonConcreteType)