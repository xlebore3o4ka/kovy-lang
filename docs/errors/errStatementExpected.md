# ERR-errStatementExpected

<!-- doc-id: ERR-errStatementExpected -->
<!-- kind: errStatementExpected -->
<!-- status: emitted -->
<!-- phase: parser -->

<a id="ERR-errStatementExpected"></a>
## Message

Locale key: `errStatementExpected`.

```text
@0 is not a statement
  Only the statement is allowed in this position
```

| Placeholder | Meaning |
|---|---|
| `@0` | the actual token description (`Token.mean`) |

## Emitters

- `Parser.parsePrimary`: the parser is at the root of an expression statement
  and the first token is not a valid primary. It reports this error, skips to
  the next separator, and returns an invalid expression.

`parseStmt` sets `highLevelExpr = true` immediately before parsing a statement
that does not start with a declaration or a control keyword. `parsePrimary`
consumes that flag once, so only the root primary uses this error. Invalid
primaries nested inside a larger expression use
`ERR-errExpressionExpected` instead.

## Triggers

<a id="TRG-errStatementExpected-right-paren"></a>
### TRG-errStatementExpected-right-paren

<!-- expect-errors: errStatementExpected -->
```kovy
)
```

A closing parenthesis cannot start a statement.

<a id="TRG-errStatementExpected-else"></a>
### TRG-errStatementExpected-else

<!-- expect-errors: errStatementExpected -->
```kovy
else:
```

`else` has no standalone statement production. It is only consumed by
`parseBranch` after an `if`.

<a id="TRG-errStatementExpected-bang"></a>
### TRG-errStatementExpected-bang

<!-- expect-errors: errStatementExpected -->
```kovy
!true
```

`!` is lexed as `tkBang` but has no grammar production. It is not logical
negation; use `not`.

<a id="TRG-errStatementExpected-keyword-prefix"></a>
### TRG-errStatementExpected-keyword-prefix

<!-- expect-errors: errStatementExpected -->
```kovy
mut int x = 1
```

`mut` belongs after a declaration type, not before it. It cannot start an
expression statement.

## Near misses

- `int = 1` starts with a type and goes through declaration parsing; it is
  `ERR-errSyntax`, not this error.
- An invalid character such as `@` becomes `tkInvalid`, which
  `parsePrimary` accepts as an invalid expression without this error.
- A nested bad primary uses `ERR-errExpressionExpected`; for example
  `int x = 1 + )`.

## Cascades

Recovery skips to `EOS`, `EOF`, or dedent. The invalid expression statement is
kept, and sema ignores invalid expressions because their type is `typeError`.
The minimal reproducers produce only this error.

## Tests

- Parser tests are indirect.
- `tests/tFunc.nim` exercises valid expression statements.

## Related

- [SYN-STMT-EXPR](../language/statements.md#SYN-STMT-EXPR)
- [ERR-errExpressionExpected](errExpressionExpected.md#ERR-errExpressionExpected)
- [SYN-LEX-OPERATORS](../language/lexical.md#SYN-LEX-OPERATORS)