# ERR-errTypeSyntax

<!-- doc-id: ERR-errTypeSyntax -->
<!-- kind: errTypeSyntax -->
<!-- status: emitted -->
<!-- phase: parser -->

<a id="ERR-errTypeSyntax"></a>
## Message

Locale key: `errTypeSyntax`.

```text
Syntax error for a type
```

No placeholders and no addinfo.

## Emitters

- `Parser.parseType`: the first token of a type is not `int`, `bool`, or
  `void`. It reports this error, skips to the next separator, and returns
  `typeError`.

That emitter is reached from declaration types (only after a token already
passed `isType`), function parameter types, function return types, function
type argument types, `alloc` element types, and array `of T` element types.
The parser does not accept user-defined type names, so any non-keyword in a
type position is this error.

## Triggers

<a id="TRG-errTypeSyntax-alloc-element"></a>
### TRG-errTypeSyntax-alloc-element

<!-- expect-errors: errTypeSyntax -->
```kovy
int* p = alloc 1 of x
```

`alloc` accepts any expression as its count, so `1` is valid; `x` is not a
type. Sema never sees a valid element type.

<a id="TRG-errTypeSyntax-array-element"></a>
### TRG-errTypeSyntax-array-element

<!-- expect-errors: errTypeSyntax -->
```kovy
int* p = [] of x
```

The explicit array element type must be `int`, `bool`, or `void`.

<a id="TRG-errTypeSyntax-function-type-argument"></a>
### TRG-errTypeSyntax-function-type-argument

<!-- expect-errors: errTypeSyntax, errSyntax -->
```kovy
int(x) f
```

The function type parser enters `parseType` for its argument and gets `x`.
After recovery, the declaration parser also fails to find the declared name.

<a id="TRG-errTypeSyntax-parameter-type"></a>
### TRG-errTypeSyntax-parameter-type

<!-- expect-errors: errTypeSyntax, errSyntax -->
```kovy
int f(1):
  return 1
```

A parameter must start with a type; `1` is not one. Recovery consumes to the
end of the parameter line, and the parser then fails to find the expected
identifier.

## Near misses

- `void` is syntactically a valid type even in positions where sema or code
  generation later rejects it.
- `mut int` is not a type syntax form at declaration level. `mut` before a
  type starts an expression statement and normally produces
  `ERR-errStatementExpected` instead.
- A missing type after `of` at end of line is also `errTypeSyntax`, because
  the next token is not a base type.

## Cascades

Recovery skips to an `EOS`, so `errTypeSyntax` is often the only diagnostic.
When the failed type belongs to a parameter list or function type, the parser
can then emit `errSyntax` for a now-missing identifier or closing token. Sema
receives `typeError` and suppresses further type errors.

## Tests

- `tests/tTypes.nim`: valid primitive, pointer, and function type syntax
- Documentation reproducers: above

## Related

- [SYN-TYPE-SYNTAX](../language/types.md#SYN-TYPE-SYNTAX)
- [SYN-GRAMMAR-TYPES](../language/grammar.md#SYN-GRAMMAR-TYPES)
- [ERR-errSyntax](errSyntax.md#ERR-errSyntax)