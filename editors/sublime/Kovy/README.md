# Kovy for Sublime Text

This package provides Kovy syntax highlighting, the docs-matching color
schemes, smart indentation, and a dynamic diagnostic panel. Diagnostics are
delivered by the [LSP package](https://lsp.sublimetext.io/) through the Kovy
language server in `editors/lsp/kovy_lsp.py`, so error squiggles, gutter
marks, hover text, and diagnostic navigation all use the same language-server
session.

## Install

1. Install **LSP** from Package Control (`Ctrl+Shift+P` → **Package Control:
   Install Package** → `LSP`). The Kovy diagnostics require LSP; syntax
   highlighting, smart Enter, and the color schemes work without it.
2. Copy or symlink this directory into Sublime Text's `Packages` directory and
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

The package expects the repository checkout layout: the language server is
loaded from `editors/lsp/kovy_lsp.py`, two directories above
`editors/sublime/Kovy`.  If you keep the server elsewhere, set
`kovy_lsp_server` to its absolute path.

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

## How diagnostics work

`Kovy.sublime-settings` is both the syntax settings file for `source.kovy` and
the LSP server configuration.  You do not need a separate entry in
`Packages/User/LSP.sublime-settings`.

The server runs:

```text
python3 editors/lsp/kovy_lsp.py --stdio
```

and asks the compiler for diagnostics with:

```text
kovy check --json - --name <document path>
```

The compiler remains the single source of truth.  The server does not parse
Kovy independently.

### Finding `kovy`

The language server resolves the compiler in this order:

1. `kovyPath` in `initialization_options` (set from `kovy_executable` in
   `Kovy.sublime-settings` when non-empty);
2. the `KOVY_BIN` environment variable;
3. `kovy` on `PATH`;
4. a `bin/kovy` (or `bin/kovy.exe`) found by walking up from the current file
   and the open workspace folders.

For a source checkout, the fourth rule finds `./bin/kovy` automatically.  Set
`kovy_executable` only when the compiler is installed somewhere unusual:

```json
{
  "kovy_executable": "/home/me/kovy-lang/bin/kovy"
}
```

## Commands and keys

| Command Palette entry | Key | Action |
|---|---|---|
| `Kovy: Show Diagnostic Details` | `Ctrl+Alt+K` (`Cmd+Alt+K`) | Toggle the details panel |
| `Kovy: Next Diagnostic` | `F4` | Jump to the next error |
| `Kovy: Previous Diagnostic` | `Shift+F4` | Jump to the previous error |
| `Kovy: Restart Language Server` | | Restart the Kovy server |

The details panel shows the diagnostic under the caret using the compiler's
own layout:

```text
/home/me/game.kovy(13,2) [errUnknownSymbol] sema
  |
  | int value = conter
  V             ~~~~~~
Unknown symbol: 'conter'
  Perhaps you meant 'counter'?
```

It includes the kind, phase, file, column, line, source line, message, and
`addinfo`.  The `(column,line)` location and the `|` / `V` layout match the
`kovy check` output.  The panel is a normal read-only output panel, so it can be
selected and copied with the mouse.  In `"manual"` mode it stays open and keeps
updating as the caret moves; `"auto"` also opens and closes it automatically.

### Smart Enter

`Enter` after a block-opening `:` inserts a newline and adds exactly one
indentation level.  Other lines keep their current indentation.  Set
`kovy_smart_enter` to `false` to use Sublime's normal Enter behaviour.

### No comment shortcuts

Kovy has no comments, and `#` is the dereference operator.  `Ctrl+/` and
`Ctrl+Shift+/` (`Cmd+/` and `Cmd+Shift+/` on macOS) show a status-bar reminder
instead of inserting `#`.  The guard only applies to `source.kovy`.

## Settings

`Kovy.sublime-settings` is applied automatically to `source.kovy`.  It also
contains the syntax-specific editor settings (two spaces, no wrapping) and the
default dark color scheme.

### Package settings

| Setting | Default | Meaning |
|---|---|---|
| `kovy_python` | `""` | Python interpreter for the language server; empty auto-detects `python3` or `python` |
| `kovy_lsp_server` | `""` | Path to `kovy_lsp.py`; empty uses `editors/lsp/kovy_lsp.py` in this checkout |
| `kovy_executable` | `""` | Compiler path; empty lets the server auto-detect `bin/kovy` |
| `kovy_details_panel` | `"manual"` | `"manual"` (keybinding only), `"auto"` (show when the caret enters an error and hide when it leaves), or `"off"` |
| `kovy_smart_enter` | `true` | Add one indentation level after a block-opening `:` |

### Language-server settings

These are passed to the language server under `initialization_options` and
`settings.kovy`.

| Setting | Default | Meaning |
|---|---|---|
| `kovyPath` | `""` | Compiler path; empty means auto-detect |
| `noNimgen` | `false` | Pass `--no-nimgen` (faster, skips `errNonConcreteType`) |
| `locale` | `""` | Pass `--locale <name>` |
| `localePath` | `""` | Pass `--locale-path <path>` |
| `extraArgs` | `[]` | Extra arguments inserted before `--name` |
| `debounceMs` | `300` | Delay before checking after a change |
| `timeoutMs` | `20000` | Per-check process timeout |
| `checkOnOpen` | `true` | Check when a document opens |
| `checkOnChange` | `true` | Check after changes |
| `checkOnSave` | `true` | Check after saves |

Example:

```json
{
  "kovy_executable": "/home/me/kovy-lang/bin/kovy",
  "kovy_details_panel": "auto",
  "initialization_options": {
    "noNimgen": true,
    "debounceMs": 600
  }
}
```

`noNimgen` is useful for very fast feedback, but it skips the `nimgen` phase and
therefore does not report `errNonConcreteType`.

## Color schemes

- `Kovy.sublime-color-scheme` — dark scheme matching the documentation.
- `Kovy Light.sublime-color-scheme` — light scheme matching the docs light theme.

The dark scheme is selected by `Kovy.sublime-settings`.  Switch to the light
one with **UI: Select Color Scheme** or by setting `color_scheme` to
`Packages/Kovy/Kovy Light.sublime-color-scheme`.

## Limitations

Diagnostics, hover text, and next/previous diagnostic navigation are available.
Go-to-definition, completion, and rename still belong to future language-server
work; the compiler only exposes diagnostics today.

Diagnostics are computed for the current buffer only.  Kovy files are compiled
independently, and `kovy check` takes stdin, so the server never writes a
temporary file or changes the document on disk.