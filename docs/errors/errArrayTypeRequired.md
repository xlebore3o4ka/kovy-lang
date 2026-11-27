# ERR-errArrayTypeRequired

<!-- doc-id: ERR-errArrayTypeRequired -->
<!-- kind: errArrayTypeRequired -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errArrayTypeRequired"></a>
## Message

Locale key: `errArrayTypeRequired`.

```text
Cannot infer the element type of an empty array literal
  Add an element or specify the element type with `of T`
```

No placeholders. The addinfo is always present and contains literal backticks
around `of T`.

## Emitters

- `Sema.visit(ArrayLit)`: the literal has no explicit `of T` and zero elements.

The declared variable type does not participate. `bool* p = []` still fails
because the literal itself has no element to infer from; `[] of bool` succeeds.

## Triggers

<a id="TRG-errArrayTypeRequired-declaration"></a>
### TRG-errArrayTypeRequired-declaration

<!-- expect-errors: errArrayTypeRequired -->
```kovy
int* p = []
```

No explicit element type and no elements.

<a id="TRG-errArrayTypeRequired-bool-declaration"></a>
### TRG-errArrayTypeRequired-bool-declaration

<!-- expect-errors: errArrayTypeRequired -->
```kovy
bool* p = []
```

The declared pointer type is not used for inference, so this fails the same
way.

<a id="TRG-errArrayTypeRequired-in-loop"></a>
### TRG-errArrayTypeRequired-in-loop

<!-- expect-errors: errAllocInLoop, errArrayTypeRequired -->
```kovy
while true:
  int* p = []
  break
```

The loop check runs first; the empty literal check follows.

<a id="TRG-errArrayTypeRequired-explicit-ok"></a>
### TRG-errArrayTypeRequired-explicit-ok

<!-- expect-errors: OK -->
```kovy
int* p = [] of int
```

This near miss is accepted: an explicit element type supplies the information
the empty literal lacks.

## Near misses

- `[] of int`, `[] of bool`, and `[] of T*` are accepted for any concrete
  element type.
- `[] of void` is `ERR-errAllocVoid`.
- A non-empty literal infers from its first element, so it does not reach this
  error.
- An explicit element type with a syntax error is `ERR-errTypeSyntax`.
- An array literal in a loop with no explicit type and no elements produces
  both this error and `ERR-errAllocInLoop`.

## Cascades

The literal returns `typeError`, suppressing an enclosing `errDoesNotFit`.
Code generation is not reached by the documented test driver when this error
exists. For a valid empty literal with an explicit type, nimgen emits an
`array[0, T]` allocation and returns a pointer to the zero-length storage.

## Tests

- `tests/tSema.nim`: empty array literals and explicit element types
- `tests/tPtr.nim`: array literal element types

## Related

- [SYN-ARRAY-LITERAL](../language/arrays.md#SYN-ARRAY-LITERAL)
- [SEM-ARR-INFERENCE](../language/arrays.md#SEM-ARR-INFERENCE)
- [INT-RUNTIME-ARRAYLIT](../internals/runtime.md#INT-RUNTIME-ARRAYLIT)
- [ERR-errAllocVoid](errAllocVoid.md#ERR-errAllocVoid)