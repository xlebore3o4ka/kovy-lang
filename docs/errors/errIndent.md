# ERR-errIndent

<!-- doc-id: ERR-errIndent -->
<!-- kind: errIndent -->
<!-- status: emitted -->
<!-- phase: lexer, parser -->

<a id="ERR-errIndent"></a>
## Message

Locale key: `errIndent`.

```text
Invalid indentation
```

No placeholders and no addinfo. The lexer passes the offending character as a
placeholder, but the message does not display it. The parser passes none.

## Emitters

- `src/parser/lexer.nim`, `handleIndentation`: an indentation character differs
  from the first indentation character used in the file.
- `src/parser/parser.nim`, `parseStmts`: a statement is followed by an
  unexpected `INDENT`.
- `src/parser/parser.nim`, `parseBlock`: an inline block is followed by
  `INDENT` instead of an end of statement.

## Triggers

<a id="TRG-errIndent-mixed-indentation"></a>
### TRG-errIndent-mixed-indentation

<!-- expect-errors: errIndent -->
```kovy
if true:
  int x = 1
	int y = 2
```

The first indentation character is a space; the tab is rejected. Current
recovery treats the tab as horizontal whitespace and continues the line.

<a id="TRG-errIndent-unexpected-indent"></a>
### TRG-errIndent-unexpected-indent

<!-- expect-errors: errIndent -->
```kovy
int x = 1
  int y = 2
```

A simple statement cannot be followed by a deeper indented block. `parseStmts`
reports the indentation and stops parsing that block.

<a id="TRG-errIndent-inline-block-followed-by-indent"></a>
### TRG-errIndent-inline-block-followed-by-indent

<!-- expect-errors: errIndent -->
```kovy
if true: int x = 1
  int y = 2
```

An inline body is exactly one statement and must end with an end of statement.
The following indented line is contradictory indentation.

<a id="TRG-errIndent-inline-body-nested"></a>
### TRG-errIndent-inline-body-nested

<!-- expect-errors: errIndent -->
```kovy
if true: if true: int x = 1
  int y = 2
```

The outer inline body parses an inner inline `if`; the outer block then finds
an `INDENT` where it expects `EOS`.

## Near misses

- A bad dedent that lands between levels is `ERR-errUnknownCharacter`, not this
  error.
- Empty indented branch and loop bodies are accepted, as long as the lexer
  emits a dedent.
- A function body with only whitespace and EOF is `ERR-errEmptyFunctionBody`
  before any indentation mismatch.

## Cascades

After reporting an unexpected indent, `parseStmts` breaks out of the current
block without consuming the indentation. The top-level parser does not inspect
leftover tokens, so the reproducers above produce only `errIndent`. Mixed
indentation can be followed by ordinary parsing of the rest of the line.

## Tests

- No direct test asserts `errIndent`; all language tests use consistent spaces.
- Documentation reproducers: above

## Related

- [KOVY-INDENTATION](../language/indentation.md#KOVY-INDENTATION)
- [SEM-INDENT-BLOCK](../language/indentation.md#SEM-INDENT-BLOCK)
- [ERR-errUnknownCharacter](errUnknownCharacter.md#ERR-errUnknownCharacter)