# Verification protocol

<a id="KOVY-VERIFICATION"></a>
Documentation is verified against the working tree, not against memory.

## Required checks

1. **Error inventory.** Every `ErrorKind` in `src/errors.nim` has one page in
   `docs/errors/`, one row in `docs/errors/index.md`, and one row in
   `docs/_meta/coverage.md`.
2. **Locale inventory.** Every error page names the matching key in
   `src/error_locales/en.json`, and its placeholder table matches the message
   and addinfo.
3. **Emitter inventory.** Every `newError` call in `src/parser/lexer.nim`,
   `src/parser/parser.nim`, `src/visitors/sema.nim`, and
   `src/visitors/nimgen.nim` is represented by at least one `TRG-*` section.
4. **Syntax inventory.** Every `TokenKind`, parser production, and AST
   `NodeKind` appears in `_meta/coverage.md`.
5. **Type inventory.** Every `TypeKind` appears in `_meta/coverage.md`.
6. **Reference integrity.** All internal links resolve to an existing file and
   anchor; no anchor is duplicated.
7. **Executable examples.** Snippets marked `expect-errors` are run through
   lexer, parser, sema, and nimgen; the exact error sequence must match.
8. **Regression suite.** `nimble test --hints:off --warnings:off` passes.
9. **Example program.** `examples/rpn.kovy` is analysed with the same pipeline.

## Checker

The repository-local checker is `scripts/check_docs.nim` (built with the
project's `src/` on the path). It performs checks 1-7 and check 9, and prints
every mismatch with a file and line. Run it from the repository root:

```sh
nim c --path:src --hints:off --warnings:off -o:/tmp/check_docs scripts/check_docs.nim
/tmp/check_docs
```

The checker is intentionally independent of any Markdown renderer.

## Manual audit

Automated checks cannot decide whether prose is complete. Before a docs
release, run:

```sh
grep -RIn "newError" src/parser src/visitors
grep -RIn "err[A-Z]" src/error_locales/en.json
grep -RIn "test \"" tests
```

Map each hit to a `TRG-*`, a semantic rule, or a deliberately internal
mechanism. Record the audit date and base commit here.

## Verification record

| Date | Base commit | Result |
|---|---|---|
| 2026-11-27 | `9300df6` plus working tree | Documentation created. Checker passed 83 Markdown pages, 253 executable snippets, 40 error kinds, and 719 internal links; `nimble test --hints:off --warnings:off` passed. |