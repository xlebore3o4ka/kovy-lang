# Operator reference

<!-- doc-id: REF-OPERATORS -->
<!-- status: current -->

<a id="REF-OPERATORS"></a>
Every operator is a fixed spelling registered in `operatorsTable` in
`src/parser/tokens.nim`. There is no user-defined operator and no operator
overloading. The table groups operators by their grammar role and records the
exact typing rule in sema.

<a id="REF-OPERATORS-TABLE"></a>
## All operators and punctuation

| Spelling | `TokenKind` | Grammar role | Associativity | Sema result |
|---|---|---|---|---|
| `+` | `tkPlus` | unary and binary | left binary, prefix unary | `int` |
| `-` | `tkMinus` | unary and binary | left binary, prefix unary | `int` |
| `*` | `tkStar` | binary and type suffix | left binary | `int`; `T*` in a type |
| `/` | `tkSlash` | binary | left | `int`; emitted as Nim `div` |
| `>` | `tkGt` | binary | left | `bool` |
| `<` | `tkLt` | binary | left | `bool` |
| `>=` | `tkGe` | binary | left | `bool` |
| `<=` | `tkLe` | binary | left | `bool` |
| `==` | `tkEq` | binary | left | `bool` |
| `!=` | `tkNe` | binary | left | `bool` |
| `and` | `tkAnd` | binary word operator | left | `bool` |
| `or` | `tkOr` | binary word operator | left | `bool` |
| `not` | `tkNot` | unary word operator | prefix | `bool` |
| `#` | `tkHash` | unary prefix | prefix | pointee type |
| `addr` | `tkAddr` | unary prefix | prefix | pointer to operand type |
| `=` | `tkEquals` | assignment | right | mutable inner type |
| `:` | `tkColon` | block introducer | n/a | statement structure |
| `(` `)` | `tkLParen`, `tkRParen` | grouping, call, type | n/a | grouping/call/type |
| `[` `]` | `tkLBracket`, `tkRBracket` | array literal | n/a | pointer to element type |
| `,` | `tkComma` | list separator | n/a | none |
| `;` | `tkEOS` | statement separator | n/a | statement structure |
| `!` | `tkBang` | token only | n/a | no production |

<a id="REF-OPERATORS-UNARY"></a>
## Unary operators

`+`, `-`, `not`, `#`, and `addr` are prefix unary operators. They are
right-nested: `--x` and `not not b` parse, but `#` requires a pointer operand.

| Form | Accepted operand | Result type |
|---|---|---|
| `+x` | `numberLiteral`, `int` | `int` |
| `-x` | `numberLiteral`, `int` | `int` |
| `not x` | `boolLiteral`, `bool` | `bool` |
| `#x` | `T*` after stripping one `mut` | `T`; write permission follows the pointer expression |
| `addr x` | mutable expression | `T*`; never grants write by itself |

Anything else is `ERR-errUnaryMismatch`, except that a non-pointer `#` operand
is `ERR-errDerefNonPointer` and an immutable `addr` operand is
`ERR-errAddrFromImmutable`. Unary operators bind tighter than all binary
operators, but postfix calls bind tighter than unary operators:
`#p()` is `#(p())`.

<a id="REF-OPERATORS-BINARY"></a>
## Binary operators

| Group | Operators | Operands | Result |
|---|---|---|---|
| multiplicative | `*`, `/` | `int` / `numberLiteral` | `int` |
| additive | `+`, `-` | `int` / `numberLiteral` | `int` |
| ordered comparison | `<`, `>`, `<=`, `>=` | `int` / `numberLiteral` | `bool` |
| equality | `==`, `!=` | two integer-like or two boolean-like operands | `bool` |
| conjunction | `and` | two boolean-like operands | `bool` |
| disjunction | `or` | two boolean-like operands | `bool` |

"Integer-like" means `int` or `numberLiteral`; "boolean-like" means `bool` or
`boolLiteral`. A mutable wrapper is stripped before the table lookup. `==` and
`!=` accept mixed literal/concrete operands within the same family, so
`1 == x` and `true == b` are valid. Any other pair is `ERR-errBinaryMismatch`.

`/` is integer division and is emitted as Nim `div`, not `/`. There is no
remainder operator `%`. `and`/`or` are emitted as Nim `and`/`or`; both operands
are nevertheless visited and type-checked by sema.

<a id="REF-OPERATORS-ASSIGN"></a>
## Assignment

`=` is the only assignment operator and is right-associative: `a = b = 1`
parses as `a = (b = 1)`. The left side must be a mutable expression; the right
side is checked with `fits` against the left side's inner type. A successful
assignment yields a mutable value of that inner type.

There is no `+=`, `-=`, `*=`, `/=`, `++`, or `--`. Write `x = x + 1`.

<a id="REF-OPERATORS-TYPE"></a>
## Operators in types

`*` is ambiguous with multiplication; the parser decides by position. In a
type expression it is a postfix pointer constructor: `int*`, `int**`,
`int(bool)*`. `(` `)` in a type expression form a function type:
`R(A, B)`. `mut` is part of the argument type inside a function type, as in
`int(mut int)`.

`alloc n of T` and `[a, b] of T` use the keyword `of`, not an operator, to
introduce the element type.

<a id="REF-OPERATORS-TOKENONLY"></a>
## Tokens with no grammar production

- `!` (`tkBang`) is lexed but never accepted by `parseExpr` or `parseStmt`.
  Its presence in an expression context produces a parse error. Logical
  negation is `not`.
- `;` is a statement separator token, not an expression operator.
- `:` introduces a block after a function declaration, `if`/`elif`/`else`, or
  `while`. It is not an expression operator.

## Related

- [Token reference](tokens.md#REF-TOKENS)
- [Precedence](precedence.md#REF-PRECEDENCE)
- [Expressions](../language/expressions.md#SYN-EXPR-BINARY)
- [Lexical structure](../language/lexical.md#SYN-LEX-OPERATORS)