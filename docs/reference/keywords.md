# Keyword reference

<!-- doc-id: REF-KEYWORDS -->
<!-- status: current -->

<a id="REF-KEYWORDS"></a>
Keywords are registered in `keywordsTable` in `src/parser/tokens.nim`. They are
reserved: an identifier cannot have the same spelling, and the lexer emits the
keyword token instead of `tkIdent`. The table below lists all 19 registered
keywords with their exact token kind and where the grammar uses them.

<a id="REF-KEYWORDS-TABLE"></a>
## All keywords

| Keyword | `TokenKind` | Category | Used by |
|---|---|---|---|
| `int` | `tkInt` | type | type expressions, `parseType` |
| `bool` | `tkBool` | type | type expressions, `parseType` |
| `void` | `tkVoid` | type | type expressions, `parseType` |
| `true` | `tkTrue` | boolean literal | primary expressions |
| `false` | `tkFalse` | boolean literal | primary expressions |
| `not` | `tkNot` | unary operator | `parseUnary` |
| `or` | `tkOr` | binary operator | `parseOr` |
| `and` | `tkAnd` | binary operator | `parseAnd` |
| `mut` | `tkMut` | type modifier | declaration/parameter types and function-type arguments |
| `alloc` | `tkAlloc` | allocation | `parseAlloc` |
| `of` | `tkOf` | allocation/array suffix | `parseAlloc`, `parseArrayLit` |
| `addr` | `tkAddr` | unary operator | `parseUnary` |
| `if` | `tkIf` | control | `parseBranch` |
| `elif` | `tkElif` | control | `parseBranch` |
| `else` | `tkElse` | control | `parseBranch` |
| `while` | `tkWhile` | control | `parseWhile` |
| `break` | `tkBreak` | loop control | `parseBreak` |
| `continue` | `tkContinue` | loop control | `parseContinue` |
| `return` | `tkReturn` | return | `parseReturn` |

<a id="REF-KEYWORDS-RULES"></a>
## Rules

- Keyword recognition happens before identifier recognition, so `int` is
  always `tkInt`, even where a name would otherwise be valid.
- There are no contextual keywords. A keyword cannot be used as a declaration
  name, parameter name, or member name.
- `mut` is only a modifier. It appears after a type in a declaration or
  parameter, immediately before a function return type's `mut` position
  (`int mut f()`), and before a type inside a function type argument list
  (`int(mut int)`). It is not a statement keyword.
- `of` is only valid after an allocation count (`alloc n of T`) or after an
  array literal (`[a, b] of T`).
- `true` and `false` are keywords, not identifiers. A name such as `trueValue`
  is a normal identifier because keyword matching is exact.
- `not`, `and`, and `or` are the only word operators. `!` is a token but has no
  grammar production; see [REF-OPERATORS](operators.md#REF-OPERATORS).

<a id="REF-KEYWORDS-NOT"></a>
## Not keywords

The lexer does not register these spellings as keywords; they are ordinary
identifiers unless a future version adds them:

```text
const  var  let  proc  func  type  struct  import  in  is  nil  true_
```

There are also no `for`, `switch`, `match`, `do`, `then`, `end`, `async`,
`await`, `yield`, `class`, `object`, `enum`, `interface`, `impl`, `use`, or
`pub` keywords.

## Related

- [Token reference](tokens.md#REF-TOKENS)
- [Lexical structure](../language/lexical.md#SYN-LEX-KEYWORDS)
- [Operator reference](operators.md#REF-OPERATORS)
- [Precedence](precedence.md#REF-PRECEDENCE)