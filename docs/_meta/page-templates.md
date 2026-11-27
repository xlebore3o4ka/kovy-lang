# Page templates

<a id="KOVY-PAGE-TEMPLATES"></a>
These templates keep new documentation append-only. A page may contain more
sections than the template, but it must retain the metadata block and the
stable IDs it already published.

## Language page

```markdown
# Topic

<!-- doc-id: KOVY-TOPIC -->
<!-- status: current -->

<a id="KOVY-TOPIC"></a>
Short definition and scope.

## Syntax

<a id="SYN-TOPIC-FORM"></a>
### Form name

```kovy
example
```

Reference the canonical grammar with a link, for example
[KOVY-GRAMMAR](../language/grammar.md#KOVY-GRAMMAR).

## Semantics

<a id="SEM-TOPIC-RULE"></a>
### Rule name

Normative statement.

## Current quirks

Accepted but surprising behaviour, if any.

## Diagnostics

Links to `ERR-*` pages and specific `TRG-*` anchors.

## Tests and implementation

- `tests/tFile.nim`: test name
- `src/visitors/sema.nim`: procedure name
```

## Error page

```markdown
# ERR-errExample

<!-- doc-id: ERR-errExample -->
<!-- kind: errExample -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errExample"></a>
## Message

Exact locale message and placeholders.

## Emitters

Every source branch that can add this error.

## Triggers

<a id="TRG-errExample-condition"></a>
### TRG-errExample-condition

Complete program, expected error set, and explanation.

## Near misses

Programs that are accepted or produce a different error.

## Cascades

What else can appear together with this error.

## Tests

Existing test names, if any.
```

## Internal page

Internal pages describe representations and algorithms. They may use
`INT-*` IDs and should link to the normative language pages instead of
repeating user-facing rules.

## Example markers

Executable snippets use a hidden marker immediately before the fence:

```markdown
<!-- expect-errors: errDerefNonPointer -->
```kovy
int x = 1
int y = #x
```
```

`expect-errors: OK` means the snippet must pass lexer, parser, sema, and
nimgen. Multiple expected errors are written in order and separated by
commas. The checker compares the exact sequence of `ErrorKind`s.