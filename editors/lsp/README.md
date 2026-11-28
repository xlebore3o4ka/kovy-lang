# Kovy language server

`kovy_lsp.py` is a small, dependency-free LSP server.  It owns the LSP
transport and document lifecycle; all language intelligence currently comes
from the compiler's JSON report:

```text
kovy check --json - --name <document path>
```

Only diagnostics are implemented for now.  Hover, completion,
go-to-definition, and rename can be added later without changing the transport.

## Requirements

- Python 3.8 or newer.
- A `kovy` executable.  The server resolves it in this order:
  1. `initializationOptions.kovyPath`;
  2. the `KOVY_BIN` environment variable;
  3. `kovy` on `PATH`;
  4. a `bin/kovy` found by walking up from the document and workspace roots.

For a source checkout, the fourth rule finds `./bin/kovy` automatically.

## Run

The server uses stdio and writes LSP messages to stdout.  Logs go to stderr
when `KOVY_LSP_LOG` is set:

```bash
python3 editors/lsp/kovy_lsp.py
KOVY_LSP_LOG=1 python3 editors/lsp/kovy_lsp.py
```

`--stdio` is accepted for clients that pass it explicitly.

## Implemented protocol

Requests:

- `initialize`
- `shutdown`

Notifications:

- `initialized`
- `exit`
- `textDocument/didOpen`
- `textDocument/didChange` (full sync, incremental ranges also accepted)
- `textDocument/didSave`
- `textDocument/didClose`
- `workspace/didChangeConfiguration`
- `workspace/didChangeWorkspaceFolders`

The server publishes `textDocument/publishDiagnostics`.  Diagnostics use
1-based Kovy lines/columns internally and are converted to zero-based UTF-16
LSP positions.  The UTF-16 conversion accounts for multi-byte source text.

Each diagnostic has:

| LSP field | Value |
|---|---|
| `source` | `kovy` |
| `code` | Kovy `ErrorKind`, for example `errUnknownSymbol` |
| `message` | Localized message plus `addinfo` |
| `data.kind`, `data.phase` | Kovy metadata for future features |
| `data.sourceLine` | The original source line from the report |

## Configuration

`initializationOptions` may be flat or nested under `kovy`:

```json
{
  "kovyPath": "",
  "noNimgen": false,
  "locale": "",
  "localePath": "",
  "extraArgs": [],
  "debounceMs": 300,
  "timeoutMs": 20000,
  "checkOnOpen": true,
  "checkOnChange": true,
  "checkOnSave": true
}
```

| Option | Default | Meaning |
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

`workspace/didChangeConfiguration` accepts the same keys.  Changing the
configuration or workspace folders re-checks every open document.

## Sublime Text with the LSP package

If the `LSP` package is installed, add this to **Preferences: LSP Settings**
(or to `Packages/User/LSP.sublime-settings`):

```json
{
  "clients": {
    "kovy": {
      "enabled": true,
      "command": [
        "python3",
        "/absolute/path/to/kovy-lang/editors/lsp/kovy_lsp.py"
      ],
      "selector": "source.kovy",
      "initializationOptions": {
        "kovyPath": "/absolute/path/to/kovy-lang/bin/kovy",
        "noNimgen": false,
        "debounceMs": 300
      }
    }
  }
}
```

Do not enable both this client and the standalone **Kovy** Sublime package at
the same time if you do not want two independent sets of markers.

## Error reporting

If `kovy` is missing, cannot be started, times out, exits with code 2, or emits
invalid JSON, the server clears the document's diagnostics and sends
`window/showMessage`.  Repeating the same error does not spam the client.
Source diagnostics are exit code 1 with a valid report, which is normal.

The report contract is documented in
[`docs/reference/cli.md`](../../docs/reference/cli.md#json-output).

## Adding features

The transport and check scheduler are independent of diagnostics.  A new LSP
feature can use the same `Server.publish`/`send` helpers and add a
`textDocument/*` request handler.  For semantic navigation, prefer adding a
machine-readable command to `kovy` (for example `kovy definition --json`)
instead of reparsing Kovy in the server.