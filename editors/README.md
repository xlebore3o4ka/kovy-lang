# Editor tooling

- [`sublime/Kovy`](sublime/Kovy/README.md) — Sublime Text package with Kovy
  syntax highlighting, docs-matching color schemes, smart Enter, a dynamic
  diagnostic details panel, and LSP integration.
- [`lsp/kovy_lsp.py`](lsp/kovy_lsp.py) — dependency-free stdio LSP server with
  diagnostics from the compiler's JSON report.

The Sublime diagnostics require the Sublime `LSP` package.  The language server
is started automatically by the `Kovy` package; no manual `LSP.sublime-settings`
client entry is needed.

Both components share the same compiler contract.  They do not parse Kovy
independently; the compiler remains the single source of truth.  Semantic
features such as go-to-definition can be added to the LSP server later by
exposing new JSON commands from `kovy`.