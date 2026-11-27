# Lexical structure

<!-- doc-id: KOVY-LEXICAL -->
<!-- status: current -->

<a id="KOVY-LEXICAL"></a>
This page defines what the lexer accepts before parsing. The implementation is
`src/parser/lexer.nim`; token kinds and spellings are declared in
`src/parser/tokens.nim`.

## Source characters

<a id="SYN-LEX-CHARACTERS"></a>
### Characters

Source is a sequence of bytes interpreted as characters. Identifiers and
numbers use ASCII rules. Non-ASCII characters are not valid identifier
characters and normally produce `errUnknownCharacter`.

Spaces, tabs, carriage returns, and newlines are whitespace. `\n` and `\r`
advance lines; `\r\n` is accepted. Horizontal whitespace is skipped except
when it determines indentation (see [indentation](indentation.md#KOVY-INDENTATION)).

There are no comments. `#` is the dereference operator, not a comment marker.
There are no string, character, or raw-string literals.

## Identifiers

<a id="SYN-LEX-IDENTIFIER"></a>
### Identifiers

```ebnf
ident = ( ASCII-letter | "_" ) { ASCII-letter | ASCII-digit | "_" } ;
```

Identifiers are case-sensitive. A word that matches a keyword is always
lexed as that keyword and cannot be used as an identifier. The language has
no escaping syntax for keywords.

ASCII letters are `A-Z` and `a-z`; digits are `0-9`. Unicode letters are not
accepted by `isAlphaAscii`/`isAlphaNumeric`.

## Numbers

<a id="SYN-LEX-NUMBER"></a>
### Numbers

```ebnf
number = digit { digit } ;
```

Only unsigned decimal digit sequences are lexed. A leading `-` or `+` is a
separate unary operator. There is no hexadecimal, binary, floating-point,
exponent, digit-separator, or suffix syntax. Leading zeroes are allowed by the
lexer. The parser converts the digits to a host `int` with `parseInt`; a
literal outside the host integer range is therefore not a source-level
feature and can fail during parsing.

## Keywords

<a id="SYN-LEX-KEYWORDS"></a>
### Keywords

The complete keyword set is:

```text
addr alloc and bool break continue elif else false if int
mut not of or return true void while
```

Keywords are reserved in every context. See
[keyword reference](../reference/keywords.md#REF-KEYWORDS).

## Operators and punctuation

<a id="SYN-LEX-OPERATORS"></a>
### Operators and punctuation

The lexer greedily forms a two-character operator when the pair is registered:

| Token | Spelling | Notes |
|---|---|---|
| `tkPlus` | `+` | unary and binary |
| `tkMinus` | `-` | unary and binary |
| `tkStar` | `*` | multiplication and pointer type suffix |
| `tkSlash` | `/` | integer division; generated as Nim `div` |
| `tkLParen` | `(` | call, grouping, function type |
| `tkRParen` | `)` | closing |
| `tkLBracket` | `[` | array literal |
| `tkRBracket` | `]` | closing |
| `tkComma` | `,` | separators |
| `tkEquals` | `=` | assignment |
| `tkColon` | `:` | block introducer |
| `tkBang` | `!` | lexed but not accepted by the grammar |
| `tkHash` | `#` | dereference |
| `tkGt` | `>` | comparison |
| `tkLt` | `<` | comparison |
| `tkGe` | `>=` | comparison |
| `tkLe` | `<=` | comparison |
| `tkEq` | `==` | comparison |
| `tkNe` | `!=` | comparison |

A run of semicolons is collapsed into one statement-separator token. A
semicolon is an explicit `tkEOS`. A newline produces a pending `tkEOS` before
the next token, with duplicate separators suppressed.

`!` has a token kind and spelling but no parser production. Using it as an
expression or statement produces a parse error; it is not logical negation.
Use `not`.

## Line structure

<a id="SYN-LEX-LINES"></a>
### Line structure

The lexer emits synthetic `tkEOS` tokens at line boundaries. Leading
indentation emits `tkIndent` and `tkDedent`. The full algorithm is in
[indentation](indentation.md#KOVY-INDENTATION).

Example:

```kovy
int x = 1; int y = 2
int z = 3
```

The first line contains two statements separated by `;`; the second line is
separated by the newline-derived `tkEOS`.

## Invalid characters

<a id="SEM-LEX-INVALID"></a>
### Invalid characters

Any character that is not whitespace, an identifier start/continuation, a
digit, or part of a registered operator becomes `tkInvalid` and produces
`ERR-errUnknownCharacter`.

```kovy
@
```

See [ERR-errUnknownCharacter](../errors/errUnknownCharacter.md#ERR-errUnknownCharacter).
Inconsistent dedentation also reuses this error kind; see
[ERR-errUnknownCharacter](../errors/errUnknownCharacter.md#TRG-errUnknownCharacter-bad-dedent).

## Tests

- `tests/tFunc.nim`: parameter and declaration spacing tests exercise lexing.
- `tests/tSema.nim`: unknown-symbol and array tests exercise real programs.
- Lexer behavior is also covered indirectly by every test in `tests/`.