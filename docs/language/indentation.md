# Indentation and statement separators

<!-- doc-id: KOVY-INDENTATION -->
<!-- status: current -->

<a id="KOVY-INDENTATION"></a>
Kovy is indentation-sensitive. Blocks are introduced by `:` and are either a
single inline statement or an indented sequence of statements.

## Indentation characters

<a id="SEM-INDENT-CHARACTER"></a>
### One indentation character type per file

The lexer remembers the first indentation character it sees at the start of a
logical line. That character becomes the only accepted indentation
character for the rest of the file. A tab in one place and a space in another
is reported as `ERR-errIndent`.

The stack starts at column zero. At each non-blank line:

- More indentation than the stack top pushes a new level and emits `tkIndent`.
- Less indentation pops levels and schedules `tkDedent` tokens.
- Equal indentation emits no indentation token.
- A dedent that lands between two existing levels is reported with
  `ERR-errUnknownCharacter` (current implementation quirk), not `errIndent`.

Blank lines, including whitespace-only lines, do not create indentation
tokens. They also do not cancel a pending `tkEOS` from the previous content
line.

## Indent and dedent example

<a id="EX-INDENT-BLOCK"></a>
```kovy
if true:
  int x = 1
  int y = 2
int z = 3
```

The body is one indented level. `int z` dedents back to the global level.

The indentation sentinel is created lazily; a file that never indents never
needs an indent character.

## Statement separators

<a id="SEM-INDENT-EOS"></a>
### Newlines and semicolons

- A newline schedules a `tkEOS` before the next non-separator token.
- A run of `;` characters becomes one explicit `tkEOS`.
- Consecutive `tkEOS` tokens are suppressed by the lexer.
- `tkEOF` ends the program after pending dedents are emitted.
- A block's dedent itself separates a compound statement from what follows.

The parser accepts an inline block after `:`:

```kovy
if true: int x = 1
```

An inline block contains exactly one statement. If it is followed by an
indented block instead of an end-of-statement, the parser reports
`ERR-errIndent`.

## Parser block rules

<a id="SEM-INDENT-BLOCK"></a>
### Parser block rules

For `if`, `elif`, `else`, and `while`, `parseBlock` requires a `:`. After the
colon:

- If the next token is `tkIndent`, the parser reads statements until
  `tkDedent`.
- Otherwise it parses exactly one statement as an inline block.
- An inline block must be followed by an end of statement; contradictory
  indentation is `ERR-errIndent`.
- Empty inline bodies are not possible: `if true:` followed directly by
  `else:` or another token in statement position is a parse error.
- An indented block may be empty for `if`/`while`, but a function body is
  checked separately and an empty function body is
  `ERR-errEmptyFunctionBody`.

Function declarations use the same block parser but additionally require a
non-empty body when the `:` is present. A function declaration without `:` is
a forward declaration, not an empty body.

## Current quirks

<a id="SEM-INDENT-QUIRKS"></a>
- A bad dedent (for example, four spaces then two spaces when the stack has
  zero and four) is reported as `errUnknownCharacter` with a space character,
  even though no invalid character was read.
- Mixing tabs and spaces reports `errIndent` and the offending character is
  later skipped as horizontal whitespace.
- A function declaration without `:` is silently treated as a forward
  declaration even when a statement follows on the same line. The parser
  deliberately skips the usual separator check after `nkFuncDecl`.
- The parser's unexpected-indentation diagnostic is `errIndent`; the lexer's
  mixed-indentation diagnostic is also `errIndent`.

## Related errors

- [ERR-errIndent](../errors/errIndent.md#ERR-errIndent)
- [ERR-errUnknownCharacter](../errors/errUnknownCharacter.md#ERR-errUnknownCharacter)
- [ERR-errEmptyFunctionBody](../errors/errEmptyFunctionBody.md#ERR-errEmptyFunctionBody)
- [ERR-errSyntax](../errors/errSyntax.md#ERR-errSyntax)

## Implementation

- `src/parser/lexer.nim`: `handleIndentation`, `handleIndentDedent`,
  `nextTok`, `emitDedentsIfNeeded`.
- `src/parser/parser.nim`: `parseBlock`, `parseStmts`.