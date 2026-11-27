# Error system internals

<!-- doc-id: INT-ERROR-SYSTEM -->
<!-- status: current -->

<a id="INT-ERROR-SYSTEM"></a>
Diagnostics are represented by `ErrorKind`, `Error`, `ErrorContext`, and
`FileTracker` in `src/errors.nim`. Messages and addinfo templates live in
`src/error_locales/en.json`.

## Data model

<a id="INT-ERROR-MODEL"></a>
### Data model

```nim
Error = object
  kind: ErrorKind
  placeholders: seq[string]
  length: Natural
  col: Positive
  line: Positive
  file: Natural

ErrorContext = ref object
  errors: seq[Error]
  placeholders: Table[string, tuple[message, addinfo: string]]
```

`Error` stores a numeric file id, not a path. `FileTracker` interns names and
stores `source.splitLines()` for display. The same tracker used for lexing must
be used for formatting.

`ErrorContext` is created by `newErrorContext(jsonPath)`. If the locale file
does not exist, construction raises `LocaleLoadError` with
`can't open file '<path>': No sush file or directory` (the misspelling is in
the source). Locale objects are loaded only when they are JSON objects with a
`message` field; `addinfo` defaults to an empty string.

## Adding errors

<a id="INT-ERROR-ADD"></a>
### Adding errors

- Lexer, parser, sema, and nimgen all call `newError(kind, file, line, col,
  length, placeholders...)`.
- There is no deduplication. The same condition can add several errors.
- There is no severity level; every `Error` is an error.
- `hasErrors` is simply `errors.len > 0`.
- Component helpers usually use the offending token's lexeme length. Some
  lexer errors use length 1. The parser's `newError` skips tokens to the next
  `EOS`, `EOF`, or `Dedent` after recording a syntax error.
- Error ordering is insertion order.

## Placeholder syntax

<a id="INT-ERROR-PLACEHOLDERS"></a>
### Placeholder syntax

Locale strings use `@` followed by an optional modifier and a decimal index.
The formatter scans until a digit, then reads the index digits.

| Form | Result |
|---|---|
| `@0` | raw placeholder 0 |
| `@q0` | placeholder 0 wrapped in single quotes |
| `@c0` | placeholder 0 wrapped in backticks |
| `@f0` | placeholder 0 parsed as a file id and converted to a path |
| `@n0` | raw placeholder 0; no color is applied by the current formatter |
| unknown modifier | raw value |

If the index is out of range, the placeholder is silently omitted. An `@` not
followed by digits still consumes the modifier characters and emits nothing.
This is why a `newError` call with too few placeholders can produce a truncated
message rather than an exception.

`@f` expects the placeholder to be a decimal file id. A non-numeric value
would raise during formatting.

## Formatting

<a id="INT-ERROR-FORMATTING"></a>
### `formatError`

The exact layout is:

```text
<path>(<col>,<line>) [<ErrorKind>]
  |
  | <source line>
  V <spaces><markers>
<message>
  <addinfo>
```

Details:

- The location order is `(col,line)`, not the more common `(line,col)`.
- The marker is `^` when `length < 2`, otherwise `~`.
- The marker line uses `length` copies of the marker.
- The `V` line has `col - 1` spaces before the marker.
- The source line is empty if the requested line is out of range.
- Message and addinfo are formatted with the same placeholder rules.
- Addinfo is omitted when it is empty.
- For `errUnknownSymbol`, addinfo is also omitted when there is no suggestion
  (fewer than two placeholders, or the suggestion is empty).
- A multi-line addinfo is printed after two leading spaces; embedded newlines
  keep their own indentation from the locale string.

Example:

```text
file.kovy(7,3) [errDoesNotFit]
  |
  | bool x = 1
  V        ^
Type `int` does not fit into type `bool`
```

## Locale keys

<a id="INT-ERROR-LOCALES"></a>
### Locale keys

Every current `ErrorKind` has a key with the same name. The locale file also
contains a `FORMAT_INFO` array; it is documentation for translators and is not
loaded as an error because it has no `message` field.

`errIllformedArgument` has a locale entry but no emitter in `src/`. Its status
is `declared-not-emitted`.

## Status vocabulary

<a id="INT-ERROR-STATUS"></a>
### Status vocabulary

| Status | Meaning |
|---|---|
| `emitted` | at least one reachable source program reaches an emitter |
| `guarded` | the emitter exists but no source trigger is known |
| `declared-not-emitted` | the enum value and locale entry exist, but no source code adds it |

No current `ErrorKind` is currently `guarded`: `errAmbiguousCall` has a
concrete trigger using two overloads with crossed mutable parameters, and
`errIllformedArgument` is the only declared-not-emitted value.

## Adding a new error

1. Add the enum value to `src/errors.nim`.
2. Add a locale entry with message, addinfo, and placeholders.
3. Add the emitter and a test.
4. Add `docs/errors/err<Kind>.md` and its `TRG-*` sections.
5. Add one row to `docs/errors/index.md` and one row to
   `docs/_meta/coverage.md`.

Do not reuse an existing kind for a new condition. Do not reuse an old page or
anchor for a different error.

## Implementation

- `src/errors.nim`: data model, formatting, locale loading
- `src/error_locales/en.json`: messages and addinfo
- `docs/_meta/page-templates.md`: error-page template
- [KOVY-ERRORS-INDEX](../errors/index.md#KOVY-ERRORS-INDEX): complete table