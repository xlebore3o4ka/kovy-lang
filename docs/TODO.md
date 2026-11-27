# Documentation plan

This file is the implementation plan for the `docs/` tree. It is written before
the reference pages so that the structure, reference scheme, and coverage rules
are fixed. Checkboxes are updated as the work is completed.

## Goals

- Document every current syntax form of Kovy.
- Document current semantics as implemented, not desired semantics.
- Document every existing `ErrorKind` and every way to trigger it.
- Give every useful statement a stable ID and anchor.
- Make new features/errors append-only additions to a small number of files.
- Keep documentation verifiable against `src/` and `tests/`.

## Non-goals

- No roadmap features.
- No lifetime-taint analysis as implemented behavior.
- No claims that the compiler has features it does not have.

## Principles

- `src/` and `tests/` are the source of truth.
- One topic per small file.
- No source line numbers; refer to symbols and tests.
- IDs are slugs, never numeric sequences.
- Existing IDs are never reused or renumbered.
- Current quirks are documented explicitly.
- Global indexes are the only cross-cutting files that need new rows.

## Directory layout

```text
docs/
  README.md
  TODO.md
  _meta/
    id-scheme.md
    page-templates.md
    coverage.md
    verification.md
  language/
    overview.md
    lexical.md
    indentation.md
    grammar.md
    types.md
    declarations.md
    expressions.md
    statements.md
    functions.md
    overloads.md
    mutability.md
    pointers.md
    arrays.md
    scopes.md
    control-flow.md
    pipeline.md
  errors/
    index.md
    errUnknownCharacter.md
    ... one file per ErrorKind ...
  internals/
    ast.md
    types.md
    sema.md
    nimgen.md
    runtime.md
    error-system.md
  reference/
    tokens.md
    keywords.md
    operators.md
    precedence.md
    type-compatibility.md
    syntax-index.md
    semantics-index.md
    error-index.md
    test-map.md
  guides/
    hello-world.md
    functions-overloads.md
    pointers-alloc.md
    arrays.md
    rpn.md
```

## Stable IDs

- `KOVY-*` - document or top-level section.
- `SYN-*` - syntax construct.
- `SEM-*` - semantic rule.
- `ERR-*` - error page; canonical form is `ERR-<ErrorKind>`.
- `TRG-*` - concrete error trigger.
- `EX-*` - reusable example.
- `INT-*` - compiler-internal mechanism.

Anchors are explicit HTML anchors, for example
`<a id="SEM-PTR-WRITE-GRANT"></a>`. Links always point at an ID, never at a
heading title. Deprecated IDs stay in place with a status note and a link to
the replacement.

## Page templates

Language pages contain: scope, syntax, semantics (`SEM-*` rules), current
quirks, related errors, tests, implementation references.

Error pages contain: exact `ErrorKind`, phase, status, message, placeholders,
emitter locations, one `TRG-*` section per way to trigger the error, near
misses, cascades, related errors, and tests.

Internal pages describe AST, types, sema, nimgen, runtime, and error
formatting without duplicating the normative language reference.

## Completeness inventory

- All `TokenKind`s, keywords, operators, and lexical rules.
- All parser productions, precedence, associativity, and block forms.
- All AST node kinds and fields.
- All `TypeKind`s and `fits` / `conversionCost` rules.
- All sema rules, scopes, contexts, overload resolution, and return analysis.
- All nimgen transformations and runtime helpers.
- All `ErrorKind`s, locale entries, placeholders, and emitter branches.
- All existing tests mapped to syntax/semantics/error IDs.

`_meta/coverage.md` is the authoritative completeness matrix.

## Error catalogue

One file per `ErrorKind` under `docs/errors/`. `errors/index.md` is the only
global error index. Each `TRG-*` section contains a complete reproducible
snippet and expected error ordering. Declared-but-unreachable errors are
marked `status: declared-not-emitted`.

## Maintenance rules

Adding a language feature:

1. Add a `SYN-*` section to one topic page.
2. Add the matching `SEM-*` rule to that page.
3. Add rows to `_meta/coverage.md` and the relevant reference index.
4. Add executable examples and a test mapping.
5. Add a new error page only if a new `ErrorKind` was introduced.

Adding an error:

1. Create `errors/errNew.md` from the template.
2. Add one row to `errors/index.md`.
3. Add one row to `_meta/coverage.md`.
4. Link it from the owning language page when useful.

Existing pages are not rewritten for additions.

## Validation

- A docs checker validates error pages, indexes, IDs, local links, tokens,
  AST kinds, `TypeKind`s, and locale keys.
- Executable `kovy` snippets are extracted from Markdown and checked against
  their expected `ErrorKind` sets.
- `nimble test --hints:off --warnings:off` remains green.
- `examples/rpn.kovy` is analysed by the same checks.
- The verification protocol is recorded in `_meta/verification.md`.

## Implementation order

- [x] Scaffold `docs/` and meta pages.
- [x] Extract source inventories and fill `_meta/coverage.md`.
- [x] Write lexical, indentation, grammar, and precedence pages.
- [x] Write types, declarations, and expressions.
- [x] Write functions, overloads, and mutability.
- [x] Write pointers, arrays, scopes, control flow, and pipeline.
- [x] Write internals.
- [x] Write `errors/index.md` and all error pages.
- [x] Write guides and annotated examples.
- [x] Fill reference indexes and test map.
- [x] Add and run documentation checks.
- [x] Perform final coverage audit.

## Acceptance criteria

- Every `ErrorKind` has a page and all emitter paths have `TRG-*` entries.
- Every token, AST kind, type kind, parser production, and visitor is covered.
- Every syntax form and current semantic rule is documented.
- Examples are executable or explicitly marked otherwise.
- No broken internal links or duplicate IDs.
- Adding a new error needs only a new page and index rows.