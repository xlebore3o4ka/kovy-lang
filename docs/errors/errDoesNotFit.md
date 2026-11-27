# ERR-errDoesNotFit

<!-- doc-id: ERR-errDoesNotFit -->
<!-- kind: errDoesNotFit -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errDoesNotFit"></a>
## Message

Locale key: `errDoesNotFit`.

```text
Type @c0 does not fit into type @c1
```

| Placeholder | Meaning |
|---|---|
| `@c0` | actual type string |
| `@c1` | expected type string |

No addinfo.

## Emitters

- `Sema.visit(Decl)`: an initializer does not fit the declared type.
- `Sema.visit(Branch)`: an `if` condition does not fit `bool`.
- `Sema.visit(Branch)`: an `elif` condition does not fit `bool`.
- `Sema.visit(While)`: a `while` condition does not fit `bool`.
- `Sema.visit(Return)`: a return value does not fit the declared return type.
- `Sema.visit(ArrayLit)`: a non-first element does not fit the inferred or
  explicit element type.

Assignment mismatch is **not** this error; it uses
`ERR-errBinaryMismatch`.

## Triggers

<a id="TRG-errDoesNotFit-initializer"></a>
### TRG-errDoesNotFit-initializer

<!-- expect-errors: errDoesNotFit -->
```kovy
bool x = 1
```

The actual type is the internal literal type and is printed as
`numberLiteral`; the expected type is `bool`. Arithmetic such as `1 + 1`
would already have produced concrete `int`.

<a id="TRG-errDoesNotFit-void-initializer"></a>
### TRG-errDoesNotFit-void-initializer

<!-- expect-errors: errDoesNotFit -->
```kovy
void x = 1
```

`void` is not a value type in the `fits` table. This declaration is accepted
without an initializer, but an initialized `void` declaration fails here.

<a id="TRG-errDoesNotFit-if-condition"></a>
### TRG-errDoesNotFit-if-condition

<!-- expect-errors: errDoesNotFit -->
```kovy
if 1:
  int x = 1
```

The condition must fit `bool`.

<a id="TRG-errDoesNotFit-elif-condition"></a>
### TRG-errDoesNotFit-elif-condition

<!-- expect-errors: errDoesNotFit -->
```kovy
if true:
  int x = 1
elif 1:
  int y = 2
```

Each `elif` condition is checked independently and uses the main `if` token as
the diagnostic node.

<a id="TRG-errDoesNotFit-while-condition"></a>
### TRG-errDoesNotFit-while-condition

<!-- expect-errors: errDoesNotFit -->
```kovy
while 1:
  int x = 1
```

The loop condition must fit `bool`.

<a id="TRG-errDoesNotFit-return-value"></a>
### TRG-errDoesNotFit-return-value

<!-- expect-errors: errDoesNotFit -->
```kovy
int f():
  return true
```

The value fits neither `int` nor a mutable return conversion.

<a id="TRG-errDoesNotFit-array-element"></a>
### TRG-errDoesNotFit-array-element

<!-- expect-errors: errDoesNotFit -->
```kovy
int* p = [1, true]
```

The first element infers `int`; the second is a boolean literal. Every
remaining element is checked independently, so several mismatches can be
reported.

## Near misses

- A literal fits its concrete type: `int x = 1` and `bool x = true` are valid.
- A mutable value fits an immutable expected type through `fits`.
- `void` return compatibility is handled before `fits`, so a void function
  returning a value gets `ERR-errVoidReturnValue`, not this error.
- Assignment uses `ERR-errBinaryMismatch`.
- An unknown symbol or invalid expression produces `typeError`, which `fits`
  treats as compatible.

## Cascades

A failed declaration initializer still inserts the symbol. A failed branch
condition does not stop analysis of the body. A failed return still counts as a
return for all-paths-return analysis. An array literal failure returns
`typeError` to its enclosing declaration, so there is no second fit error at
the declaration.

## Tests

- `tests/tSema.nim`: mismatched array elements with and without explicit type
- `tests/tPtr.nim`: non-number allocation count uses a different error
- `tests/tFunc.nim`: valid return paths and types

## Related

- [SEM-TYPE-FITS](../language/types.md#SEM-TYPE-FITS)
- [SEM-ARR-INFERENCE](../language/arrays.md#SEM-ARR-INFERENCE)
- [ERR-errBinaryMismatch](errBinaryMismatch.md#ERR-errBinaryMismatch)
- [ERR-errVoidReturnValue](errVoidReturnValue.md#ERR-errVoidReturnValue)