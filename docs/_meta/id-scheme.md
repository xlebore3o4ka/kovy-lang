# Stable ID scheme

<a id="KOVY-ID-SCHEME"></a>
Every reference-worthy statement in this documentation has an ID. IDs are
ASCII slugs, written in upper case with hyphens. They are stable: an ID is
never renumbered and never reused for a different meaning.

## Namespaces

| Prefix | Meaning | Example |
|---|---|---|
| `KOVY-*` | document or top-level topic | `KOVY-POINTERS` |
| `SYN-*` | syntax construct | `SYN-ARRAY-LITERAL` |
| `SEM-*` | semantic rule | `SEM-PTR-WRITE-GRANT` |
| `ERR-*` | diagnostic; canonical suffix is the `ErrorKind` enum value | `ERR-errDerefNonPointer` |
| `TRG-*` | one concrete way to trigger an error | `TRG-errDerefNonPointer-non-pointer` |
| `EX-*` | reusable example | `EX-PTR-ALLOC-BASIC` |
| `INT-*` | compiler-internal mechanism | `INT-NIMGEN-NAME-ENCODING` |

## Anchors

A Markdown heading does not provide a stable anchor by itself. Put an explicit
HTML anchor immediately before the heading:

```html
<a id="SEM-PTR-WRITE-GRANT"></a>
### Write permission
```

Then link to the file and the anchor:

```markdown
[write permission](#SEM-PTR-WRITE-GRANT)
```

Never link to a bare heading fragment such as `#write-permission`.

## Naming rules

- Use meaningful words, not sequence numbers.
- Use `ERR-<ErrorKind>` exactly; do not invent a shorter spelling.
- A trigger ID should identify the condition, not the test number:
  `TRG-errDoesNotFit-branch-condition`.
- One ID identifies one statement or one trigger. Do not attach an ID to a
  whole page when a section ID is more precise.

## Renaming and removal

If an `ErrorKind` is renamed or a construct is removed:

1. Keep the old page and old anchor.
2. Add a status note at the top: `status: renamed` or `status: removed`.
3. Link to the replacement ID if one exists.
4. Do not reuse the old ID for a new concept.

This keeps external references resolvable. The current status of a page is
recorded in its metadata block.

## Metadata block

Top-level pages begin with a small HTML comment block:

```html
<!-- doc-id: KOVY-POINTERS -->
<!-- status: current -->
```

Error pages use:

```html
<!-- doc-id: ERR-errDerefNonPointer -->
<!-- kind: errDerefNonPointer -->
<!-- status: emitted -->
<!-- phase: sema -->
```

The documentation checker reads these fields.