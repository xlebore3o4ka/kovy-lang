# Kovy for Sublime Text

This package provides Kovy syntax highlighting, the docs-matching color schemes,
and inline diagnostics from the compiler:

```text
kovy check --json - --name <current file>
```

Diagnostics appear as red squiggles with gutter marks.  The status bar shows a
short summary (or the message under the caret), and **Kovy: Show Diagnostics**
opens the full report in an output panel.

## Install

Copy or symlink this directory into Sublime Text's `Packages` directory and
name it `Kovy`.

From the repository root on Linux:

```bash
ln -s "$PWD/editors/sublime/Kovy" "$HOME/.config/sublime-text/Packages/Kovy"
```

macOS:

```bash
ln -s "$PWD/editors/sublime/Kovy" \
  "$HOME/Library/Application Support/Sublime Text/Packages/Kovy"
```

Windows (PowerShell, run as the current user):

```powershell
New-Item -ItemType SymbolicLink `
  -Path "$env:APPDATA\Sublime Text\Packages\Kovy" `
  -Target (Resolve-Path "editors\sublime\Kovy")
```

Alternatively, copy the directory.  Restart Sublime Text after installing or
updating the package.

The package is self-contained and does not require the Sublime `LSP` package.
The separate LSP server in `editors/lsp` is for editors that speak LSP.

### Migrating from `Packages/User/Kovy.sublime-syntax`

Earlier development copies lived in `Packages/User`.  If you installed one,
remove the old files and select **Kovy** again from **View → Syntax** for open
Kovy files.  A saved session that still points at
`Packages/User/Kovy.sublime-syntax` fails at startup with:

```text
Error loading syntax file "Packages/User/Kovy.sublime-syntax": Unable to stat ...
```

Either pick the new syntax once per open view, or close Sublime Text and replace
that path with `Packages/Kovy/Kovy.sublime-syntax` in the session files under
`Local/` before reopening.  Do not keep both copies around: they show up as two
identical `Kovy` entries in the syntax menu.

## Finding `kovy`

The plugin resolves the compiler in this order:

1. `kovy_executable` from `Kovy.sublime-settings` (or a project/syntax override);
2. the `KOVY_BIN` environment variable;
3. `kovy` on `PATH`;
4. a `bin/kovy` (or `bin/kovy.exe`) found by walking up from the current file
   and the open workspace folders.

For a source checkout, the fourth rule finds `./bin/kovy` automatically.

## Commands

| Command Palette entry | Action |
|---|---|
| `Kovy: Check File` | Run a check now and refresh diagnostics |
| `Kovy: Show Diagnostics` | Open the diagnostic panel and refresh it |
| `Kovy: Clear Diagnostics` | Remove markers and the status message |

## Settings

`Kovy.sublime-settings` is applied automatically to `source.kovy`.  It also
contains the syntax-specific editor settings (two spaces, no wrapping) and the
default dark color scheme.

| Setting | Default | Meaning |
|---|---|---|
| `kovy_executable` | `"kovy"` | Compiler path or command name |
| `kovy_check_on_open` | `true` | Check when a Kovy view is first activated |
| `kovy_check_on_save` | `true` | Check after saving |
| `kovy_check_on_type` | `true` | Re-check after a short pause while typing |
| `kovy_check_delay_ms` | `400` | Debounce for on-type checks |
| `kovy_check_timeout_ms` | `15000` | Per-check process timeout |
| `kovy_check_no_nimgen` | `false` | Pass `--no-nimgen` for a faster, sema-only check |
| `kovy_locale` | `""` | Pass `--locale <name>` |
| `kovy_locale_path` | `""` | Pass `--locale-path <path>` |
| `kovy_extra_args` | `[]` | Extra arguments inserted before `--name` |

Example:

```json
{
  "kovy_executable": "/home/me/kovy-lang/bin/kovy",
  "kovy_check_on_type": true,
  "kovy_check_delay_ms": 600,
  "kovy_check_no_nimgen": true
}
```

`kovy_check_no_nimgen` is useful for very fast feedback, but it skips the
`nimgen` phase and therefore does not report `errNonConcreteType`.

## Color schemes

- `Kovy.sublime-color-scheme` — dark scheme matching the documentation.
- `Kovy Light.sublime-color-scheme` — light scheme matching the docs light theme.

The dark scheme is selected by `Kovy.sublime-settings`.  Switch to the light
one with **UI: Select Color Scheme** or by setting `color_scheme` to
`Packages/Kovy/Kovy Light.sublime-color-scheme`.

## Limitations

Only diagnostics are implemented.  Hover, completion, go-to-definition, and
rename belong to the LSP server and will be added on top of the same
`kovy check --json` contract.

Diagnostics are computed for the current buffer only.  Kovy files are compiled
independently, and `kovy check` takes stdin, so the plugin never writes a
temporary file or changes the document on disk.