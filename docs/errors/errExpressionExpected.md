# ERR-errExpressionExpected

<!-- doc-id: ERR-errExpressionExpected -->
<!-- kind: errExpressionExpected -->
<!-- status: emitted -->
<!-- phase: parser -->

<a id="ERR-errExpressionExpected"></a>
## Message

Locale key: `errExpressionExpected`.

```text
Expected expression after @c1, got @0
  @0 is not an expression
```

| Placeholder | Meaning |
|---|---|
| `@0` | the actual token description (`Token.mean`) |
| `@1` | the token that introduced the expression position |

## Emitters

- `Parser.parsePrimary`: the first token of an expression is not a valid
  primary and the parser is not at the root of an expression statement. It
  reports this error, skips to the next separator, and returns an invalid
  expression.

This branch is reached after `=`, binary operators, unary operators, `return`,
`if`/`elif`/`while` conditions, call arguments, array elements, parenthesized
groups, allocation counts, and function-type positions that expect an
expression.

## Triggers

<a id="TRG-errExpressionExpected-after-assignment"></a>
### TRG-errExpressionExpected-after-assignment

<!-- expect-errors: errExpressionExpected -->
```kovy
int x =
```

The initializer is required after `=`. `@1` is the `=` lexeme.

<a id="TRG-errExpressionExpected-after-operator"></a>
### TRG-errExpressionExpected-after-operator

<!-- expect-errors: errExpressionExpected -->
```kovy
int x = 1 +
```

The right operand of `+` is missing. The same path handles `-`, `*`, `/`,
comparisons, `and`, `or`, and unary operators such as `not`.

<a id="TRG-errExpressionExpected-call-argument"></a>
### TRG-errExpressionExpected-call-argument

<!-- expect-errors: errExpressionExpected, errSyntax -->
```kovy
int f(int a):
  return a
int x = f(, 1)
```

The first argument position contains a comma. Recovery skips the rest of the
line, so the call's closing `)` is also missing from the recovered stream.

<a id="TRG-errExpressionExpected-array-element"></a>
### TRG-errExpressionExpected-array-element

<!-- expect-errors: errExpressionExpected, errSyntax -->
```kovy
int* p = [1,,2]
```

The second element position contains a comma. The array parser then also fails
to recover a closing bracket.

<a id="TRG-errExpressionExpected-return-at-eof"></a>
### TRG-errExpressionExpected-return-at-eof

<!-- expect-errors: errExpressionExpected, errSyntax -->
```kovy
int f():
  return
```

The source ends immediately after `return` with no newline and no `EOS`, so the
parser attempts to parse a return value. A trailing newline would instead
produce `ERR-errReturnValueExpected`.

## Near misses

- The root primary of an expression statement uses
  `ERR-errStatementExpected` instead. For example, `)` at top level is not
  reported as a missing expression.
- `[]` is a valid empty array literal until sema asks for an element type.
- A leading `-` or `+` is a unary operator, not part of a number literal.

## Cascades

`parsePrimary` recovery skips to an `EOS`, `EOF`, or dedent. In call and array
contexts this can remove the expected closing delimiter, producing a following
`errSyntax`. In return position it can remove the function body's separator and
produce a syntax error before sema runs.

## Tests

- Parser tests are indirect; no test asserts this diagnostic directly.
- `tests/tFunc.nim` contains valid calls and returns.

## Related

- [SYN-EXPR-PRIMARY](../language/expressions.md#SYN-EXPR-PRIMARY)
- [SYN-STMT-RETURN](../language/statements.md#SYN-STMT-RETURN)
- [ERR-errStatementExpected](errStatementExpected.md#ERR-errStatementExpected)