# Editor tooling

- [`sublime/Kovy`](sublime/Kovy/README.md) — self-contained Sublime Text
  package: syntax, color schemes, and inline diagnostics from
  `kovy check --json`.
- [`lsp/kovy_lsp.py`](lsp/kovy_lsp.py) — dependency-free stdio LSP server with
  diagnostics from the same JSON report.

Both components share the same compiler contract.  They do not parse Kovy
independently; the compiler remains the single source of truth.  Semantic
features such as go-to-definition can be added to the LSP server later by
exposing new JSON commands from `kovy`.