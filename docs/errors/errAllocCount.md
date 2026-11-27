# ERR-errAllocCount

<!-- doc-id: ERR-errAllocCount -->
<!-- kind: errAllocCount -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errAllocCount"></a>
## Message

Locale key: `errAllocCount`.

```text
alloc expects an integer element count, got @c0
```

| Placeholder | Meaning |
|---|---|
| `@c0` | count expression type via `diagnosticTypeStr` |

No addinfo.

## Emitters

- `Sema.visit(Alloc)`: the visited count type does not `fits` `int`.

The count is visited before this check. `fits` accepts `int` and
`numberLiteral`, and strips a `typeMutable` wrapper, so a mutable integer count
is accepted. The check runs after the element type is validated: an error or
`void` element type returns before it.

## Triggers

<a id="TRG-errAllocCount-bool"></a>
### TRG-errAllocCount-bool

<!-- expect-errors: errAllocCount -->
```kovy
int* p = alloc true of int
```

A boolean literal is not an integer count.

<a id="TRG-errAllocCount-pointer"></a>
### TRG-errAllocCount-pointer

<!-- expect-errors: errAllocCount -->
```kovy
int* q
int* p = alloc q of int
```

A pointer is not an integer count.

<a id="TRG-errAllocCount-function"></a>
### TRG-errAllocCount-function

<!-- expect-errors: errAllocCount -->
```kovy
int(int) fn
int* p = alloc fn of int
```

A function type is not an integer count.

<a id="TRG-errAllocCount-in-loop"></a>
### TRG-errAllocCount-in-loop

<!-- expect-errors: errAllocInLoop, errAllocCount -->
```kovy
while true:
  int* p = alloc true of int
  break
```

The loop check runs first, then the count check. Both diagnostics are produced.

## Near misses

- `int* p = alloc 1 of int` is valid.
- A mutable integer count such as `alloc n of int` with `int mut n` is valid.
- A count expression with `typeError` stops the allocation visit without this
  error.
- `void` element type is `ERR-errAllocVoid` and returns before the count check.
- A syntax error in the element type is `ERR-errTypeSyntax` and prevents sema
  from seeing a usable allocation.

## Cascades

The allocation returns `typeError`, suppressing an enclosing
`errDoesNotFit`. In a loop, `errAllocInLoop` may already have been added. The
count expression itself has been visited, so its own errors can precede this
one.

## Tests

- `tests/tPtr.nim`: allocation counts, including non-number counts

## Related

- [SYN-ALLOC](../language/pointers.md#SYN-ALLOC)
- [SEM-PTR-ALLOC-MEMORY](../language/pointers.md#SEM-PTR-ALLOC-MEMORY)
- [ERR-errAllocVoid](errAllocVoid.md#ERR-errAllocVoid)
- [ERR-errAllocInLoop](errAllocInLoop.md#ERR-errAllocInLoop)