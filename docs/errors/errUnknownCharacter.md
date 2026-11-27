# ERR-errUnknownCharacter

<!-- doc-id: ERR-errUnknownCharacter -->
<!-- kind: errUnknownCharacter -->
<!-- status: emitted -->
<!-- phase: lexer -->

<a id="ERR-errUnknownCharacter"></a>
## Message

Locale key: `errUnknownCharacter`.

```text
Unknown character: @q0
```

| Placeholder | Meaning |
|---|---|
| `@q0` | the offending character, single-quoted |

No addinfo is printed.

## Emitters

- `src/parser/lexer.nim`, `nextTok`: a character that is not whitespace,
  identifier start, digit, or a registered operator becomes `tkInvalid` and
  adds this error with the character.
- `src/parser/lexer.nim`, `handleIndentDedent`: a dedent that lands between
  two existing indentation levels adds this error with a space character. This
  reuses the error kind even though the input character is valid whitespace.

## Triggers

<a id="TRG-errUnknownCharacter-invalid-character"></a>
### TRG-errUnknownCharacter-invalid-character

Any unregistered character. `@` is not an operator.

<!-- expect-errors: errUnknownCharacter -->
```kovy
@
```

The lexer returns a `tkInvalid` token. The parser's primary-expression path
accepts `tkInvalid` as an invalid expression without adding a parser error, so
only the lexer error is produced.

<a id="TRG-errUnknownCharacter-bad-dedent"></a>
### TRG-errUnknownCharacter-bad-dedent

A dedent to a column that was never on the indentation stack.

<!-- expect-errors: errUnknownCharacter -->
```kovy
if true:
    int x = 1
  int y = 2
```

The stack contains `0` and `4`, then the line starts at column `2`. Popping
`4` lands at `0`, not `2`; the lexer reports the unknown-character error with
a space. This is a current quirk. See
[SEM-INDENT-QUIRKS](../language/indentation.md#SEM-INDENT-QUIRKS).

## Near misses

- Mixing tabs and spaces is `ERR-errIndent`, not this error.
- `#` is a registered dereference operator and is not an unknown character.
- Non-ASCII characters are unknown only under the ASCII identifier rules; the
  diagnostic is still this kind.

## Cascades

Multiple invalid characters produce one error each. The parser does not add a
second diagnostic for `tkInvalid` in expression position. A bad dedent can be
followed by additional parser or sema diagnostics depending on the recovered
token stream; the minimal trigger above produces only this error.

## Tests

- `tests/tPtr.nim`: `#` dereference tests confirm `#` is an operator.
- No test directly asserts a bad dedent.

## Related

- [KOVY-LEXICAL](../language/lexical.md#KOVY-LEXICAL)
- [KOVY-INDENTATION](../language/indentation.md#KOVY-INDENTATION)
- [ERR-errIndent](errIndent.md#ERR-errIndent)