# Token reference

<!-- doc-id: REF-TOKENS -->
<!-- status: current -->

<a id="REF-TOKENS"></a>
`TokenKind` is declared with the `tokenKinds` macro in
`src/parser/tokens.nim`. Each entry has an exact `mean` string used in
diagnostics. `tkNumber` and `tkIdent` additionally append the lexeme in single
quotes through `Token.mean`.

<a id="REF-TOKENS-TABLE"></a>
## All token kinds

| `TokenKind` | Spelling / origin | `mean` | Category |
|---|---|---|---|
| `tkInvalid` | unrecognized input character | `invalid token` | structural |
| `tkEOF` | end of source | `end of file` | structural |
| `tkEOS` | newline, `;`, or synthetic separator | `end of statement` | structural |
| `tkNumber` | `[0-9]+` | `number literal` + ` '<lexeme>'` | literal |
| `tkIdent` | `[A-Za-z_][A-Za-z0-9_]*`, not a keyword | `identifier` + ` '<lexeme>'` | name |
| `tkPlus` | `+` | `plus operator '+'` | operator |
| `tkMinus` | `-` | `minus operator '-'` | operator |
| `tkStar` | `*` | `star operator '*'` | operator |
| `tkSlash` | `/` | `slash operator '/'` | operator |
| `tkLParen` | `(` | `left-paren '('` | punctuation |
| `tkRParen` | `)` | `right-paren ')'` | punctuation |
| `tkLBracket` | `[` | `left-bracket '['` | punctuation |
| `tkRBracket` | `]` | `right-bracket ']'` | punctuation |
| `tkComma` | `,` | `comma ','` | punctuation |
| `tkEquals` | `=` | `equals operator '='` | operator |
| `tkColon` | `:` | `colon operator ':'` | punctuation |
| `tkBang` | `!` | `bang operator '!'` | token only |
| `tkHash` | `#` | `hash operator '#'` | operator |
| `tkGt` | `>` | `greater-than operator '>'` | operator |
| `tkLt` | `<` | `less-than operator '<'` | operator |
| `tkGe` | `>=` | `greater-or-equal operator '>='` | operator |
| `tkLe` | `<=` | `less-or-equal operator '<='` | operator |
| `tkEq` | `==` | `equality operator '=='` | operator |
| `tkNe` | `!=` | `not-equal operator '!='` | operator |
| `tkIndent` | synthetic indentation increase | `indentation` | structural |
| `tkDedent` | synthetic indentation decrease | `dedentation` | structural |
| `tkInt` | `int` | `keyword 'int'` | type keyword |
| `tkBool` | `bool` | `keyword 'bool'` | type keyword |
| `tkVoid` | `void` | `keyword 'void'` | type keyword |
| `tkTrue` | `true` | `keyword 'true'` | boolean keyword |
| `tkFalse` | `false` | `keyword 'false'` | boolean keyword |
| `tkNot` | `not` | `keyword 'not'` | operator keyword |
| `tkOr` | `or` | `keyword 'or'` | operator keyword |
| `tkAnd` | `and` | `keyword 'and'` | operator keyword |
| `tkMut` | `mut` | `keyword 'mut'` | declaration keyword |
| `tkAlloc` | `alloc` | `keyword 'alloc'` | declaration keyword |
| `tkOf` | `of` | `keyword 'of'` | declaration keyword |
| `tkAddr` | `addr` | `keyword 'addr'` | declaration keyword |
| `tkIf` | `if` | `keyword 'if'` | control keyword |
| `tkElif` | `elif` | `keyword 'elif'` | control keyword |
| `tkElse` | `else` | `keyword 'else'` | control keyword |
| `tkWhile` | `while` | `keyword 'while'` | control keyword |
| `tkBreak` | `break` | `keyword 'break'` | control keyword |
| `tkContinue` | `continue` | `keyword 'continue'` | control keyword |
| `tkReturn` | `return` | `keyword 'return'` | control keyword |

<a id="REF-TOKENS-SPELLINGS"></a>
## Operator spellings

The lexer registers these exact spellings in `operatorsTable`:

```text
;  +  -  *  /  (  )  [  ]  ,  =  >  <  >=  <=  ==  !=  !  :  #
```

`>=`, `<=`, `==`, and `!=` are recognized greedily. There is no `%`, `&`, `|`,
`^`, `~`, `@`, or string/character quoting token.

<a id="REF-TOKENS-STRUCTURAL"></a>
## Structural tokens

- `tkEOS` is produced by newlines and semicolons. Runs of separators collapse.
- `tkIndent` and `tkDedent` are synthetic; source never contains them
  literally.
- `tkInvalid` is produced for an unrecognized character and also carries the
  lexer's `errUnknownCharacter` diagnostic.
- `tkEOF` is the only token after the source ends.

<a id="REF-TOKENS-USES"></a>
## Grammar use

| Family | Used by |
|---|---|
| `tkNumber`, `tkIdent`, `tkTrue`, `tkFalse` | primary expressions |
| `tkPlus` … `tkSlash`, comparisons, `tkAnd`, `tkOr` | binary expressions |
| `tkPlus`, `tkMinus`, `tkNot`, `tkHash`, `tkAddr` | unary expressions |
| `tkLParen`, `tkComma`, `tkRParen` | calls, grouping, parameters, function types |
| `tkLBracket`, `tkRBracket`, `tkComma`, `tkOf` | array literals |
| `tkEquals` | assignment and parameter defaults |
| `tkColon` | block introducer |
| `tkStar` | pointer type suffix and multiplication |
| `tkIndent`, `tkDedent`, `tkEOS`, `tkEOF` | block and statement structure |

`tkBang` has no grammar production; see
[SYN-LEX-OPERATORS](../language/lexical.md#SYN-LEX-OPERATORS).

## Related

- [KOVY-LEXICAL](../language/lexical.md#KOVY-LEXICAL)
- [Keyword reference](keywords.md#REF-KEYWORDS)
- [Operator reference](operators.md#REF-OPERATORS)
- [Precedence](precedence.md#REF-PRECEDENCE)
- [Coverage matrix](../_meta/coverage.md#COVERAGE-TOKENS)