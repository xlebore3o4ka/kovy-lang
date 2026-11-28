# Command-line interface

<!-- doc-id: REF-CLI -->
<!-- status: current -->

<a id="REF-CLI"></a>
`kovy` is the user-facing executable. The package and source tree keep the
working name `kovylang`; `kovy` is the command users invoke.

## Usage

```bash
kovy check [options] [file|-]
kovy emit [options] <file|-> [-o <out.nim>]
kovy build [options] <file|-> [-o <binary>]
kovy help
kovy version
```

`check` runs the Kovy front-end and prints diagnostics. `emit` runs the same
pipeline and writes generated Nim plus the runtime module. `build` does the same
and then invokes the Nim compiler to produce a native binary.

## Version

`--version` prints the package version from `kovylang.nimble`. A build made with
`nimble` embeds Nimble's `NimblePkgVersion` define; a plain `nim c` build reads
the `.nimble` file at compile time. The version is not read at run time.

## Input

- A path selects a source file.
- `-` reads source from stdin.
- If no path is given and stdin is not a terminal, the command reads stdin.
- If no path is given and stdin is a terminal, the command reports a usage
  error.

`--name <name>` overrides the file name shown in diagnostics. It is useful for
stdin:

```bash
cat main.kovy | kovy check - --name main.kovy
```

## Locale

Diagnostics are localized with a JSON locale file. Two options select it:

| Option | Meaning |
|---|---|
| `--locale <name>` | Locale name, for example `en`; the file is `<name>.json` |
| `--locale-path <path>` | Exact path to a locale JSON file |

`--locale` and `--locale-path` are mutually exclusive. The default is
`--locale en`.

Without `--locale-path`, the compiler searches for the locale file in the
compiler's `error_locales` directory. It also honors `KOVY_LOCALE_DIR`, checks
next to the binary, and falls back to the repository layout when running from a
source checkout. If no file is found, `check` exits with code 2 and suggests
`--locale-path`.

## Options

| Option | Meaning |
|---|---|
| `-h`, `--help` | Show command help |
| `-v`, `--version` | Show the compiler version |
| `--locale <name>` | Locale name (default: `en`) |
| `--locale-path <path>` | Path to a locale JSON file |
| `--name <name>` | Diagnostic name override |
| `--no-nimgen` | Stop after semantic analysis (`check` only) |
| `--json` | Print diagnostics as JSON on stdout (`check` only) |
| `-o, --output <path>` | Emit/build output; `-` writes Nim to stdout (`emit` only) |

`check` runs lexer, parser, sema, and `nimgen` by default. The `nimgen` pass is
what reports `ERR-errNonConcreteType`. Use `--no-nimgen` to stop after sema.

## Build options

| Option | Meaning |
|---|---|
| `--target <name>` | Curated target alias (default: `host`) |
| `--os <name>` | Raw Nim target OS, overriding the alias |
| `--cpu <name>` | Raw Nim target CPU, overriding the alias |
| `--cc <name>` | C compiler passed to Nim |
| `--release` | Add `-d:release` |
| `--debug` | Add `--debugger:native` |
| `--nim <path>` | Nim compiler to run (default: `nim`) |
| `--nimcache <path>` | Nim cache directory |
| `--keep-nim` | Keep the generated Nim and Nim cache |

`--release` and `--debug` are mutually exclusive. Build options are rejected
for `check` and `emit`.

## Emit

```bash
kovy emit main.kovy -o main.nim
kovy emit main.kovy                 # writes main.nim
cat main.kovy | kovy emit - -o out.nim
kovy emit main.kovy -o -
```

`emit` runs lexer, parser, sema, `finalize`, and `nimgen`, then writes:

- the generated Nim to the output path;
- the runtime module `syskovy.nim` next to it.

The generated file imports `./syskovy`, so the two files must stay together.
`syskovy.nim` is embedded into the `kovy` binary at compile time with
`staticRead`; `emit` does not read the compiler source tree at run time.

Without `-o`, a file input writes `<stem>.nim` next to the source; stdin writes
`kovy-out.nim`. `-o -` writes only the generated Nim to stdout and prints a
reminder on stderr to place `syskovy.nim` next to the generated file.

`emit` returns `1` and writes no files when the source has diagnostics. It does
not invoke the Nim compiler or run the program.

## Build

```bash
kovy build main.kovy                 # writes ./main
kovy build main.kovy -o bin/app
kovy build main.kovy --release
kovy build main.kovy --target linux-arm64
kovy build main.kovy --os windows --cpu amd64 --cc gcc
```

`build` runs the same front-end as `emit`, writes the generated Nim and
`syskovy.nim` to a temporary directory, then runs:

```text
nim c --hints:off --warning:UnusedImport:off --out:<output> <generated>
```

The temporary directory and its Nim cache are removed on success. With
`--keep-nim`, they are kept and the path is printed on stderr.

Without `-o`, a file input writes the binary next to the source with the source
extension removed; a file without an extension uses `<name>.out`; stdin writes
`kovy-out` in the current directory. `-o -` is rejected because a binary cannot
be streamed as text.

`build` returns `1` without invoking Nim when the source has diagnostics. It
returns `2` when the output path is invalid, the Nim compiler cannot be started,
or Nim exits with a non-zero status; Nim's own diagnostics are passed through
on the parent streams.

### Targets

| Alias | OS | CPU |
|---|---|---|
| `host` | host default | host default |
| `linux-amd64` | `linux` | `amd64` |
| `linux-arm64` | `linux` | `arm64` |
| `linux-arm32` | `linux` | `arm` |
| `linux-i386` | `linux` | `i386` |
| `windows-amd64` | `windows` | `amd64` |
| `windows-i386` | `windows` | `i386` |
| `macos-amd64` | `macosx` | `amd64` |
| `macos-arm64` | `macosx` | `arm64` |
| `freebsd-amd64` | `freebsd` | `amd64` |

Raw `--os`, `--cpu`, and `--cc` are applied after the alias and override it,
so a preset can be adjusted without changing the command shape.

## Output

Human diagnostics are written to stderr. A clean check prints nothing and
returns `0`. Each diagnostic uses the format documented in
[INT-ERROR-FORMATTING](../internals/error-system.md#INT-ERROR-FORMATTING).

## JSON output

`--json` writes one JSON object to stdout and nothing else. Human diagnostics
are not printed in this mode. A clean check still emits a report, with an empty
`diagnostics` array, and returns `0`.

```json
{
  "schemaVersion": 1,
  "diagnostics": [
    {
      "kind": "errUnknownSymbol",
      "phase": "sema",
      "severity": "error",
      "message": "Unknown symbol: 'missing'",
      "addinfo": "",
      "line": 1,
      "column": 9,
      "length": 7,
      "sourceLine": "int x = missing"
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `schemaVersion` | Report schema, currently `1` |
| `diagnostics` | Array of diagnostics; empty when the source is clean |
| `kind` | `ErrorKind` name |
| `phase` | Pipeline stage: `lexer`, `parser`, `sema`, `finalize`, or `nimgen` |
| `severity` | Currently always `error` |
| `message` | Localized message with placeholders resolved |
| `addinfo` | Localized addinfo, or an empty string when there is none |
| `line` | 1-based line number |
| `column` | 1-based column number |
| `length` | Diagnostic marker length in characters |
| `sourceLine` | Source text of the reported line |

JSON uses `line` then `column`; the human format prints `(column,line)`.

Usage, input, and locale errors remain human-readable on stderr and return `2`,
even with `--json`.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | no diagnostics and, for `build`, a successful Nim build |
| `1` | source diagnostics were reported |
| `2` | usage, input, locale, toolchain, or output error |

Usage errors print a short message and:

```text
Try 'kovy --help' for usage.
```

## Implementation

- `src/kovy.nim`: entry point.
- `src/cli/args.nim`: command and option parsing.
- `src/cli/input.nim`: file and stdin input.
- `src/cli/locale.nim`: locale lookup.
- `src/cli/frontend.nim`: the parser/sema/nimgen pipeline and phase labels.
- `src/cli/report.nim`: the `schemaVersion: 1` JSON renderer.
- `src/cli/emit.nim`: output paths and writing the generated Nim.
- `src/cli/embedded.nim`: compile-time embedded `syskovy.nim`.
- `src/cli/build.nim`: temporary files, Nim invocation, and cleanup.
- `src/cli/targets.nim`: target aliases and raw overrides.
- `src/cli/version.nim`: compile-time package version.
- `src/cli/main.nim`: dispatch, diagnostics, exit codes.

The user-facing executable is built as `bin/kovy`.

## Tests

- `tests/tCli.nim`: argument parsing, locale lookup, input reading, the
  front-end wrapper, JSON reports, emit output, build targets, and a build
  integration test.

## Related

- [Compilation pipeline](../language/pipeline.md#KOVY-PIPELINE)
- [Command-line entry point](../language/pipeline.md#SEM-PIPELINE-CLI)
- [Error catalogue](../errors/index.md#KOVY-ERRORS-INDEX)
- [Error formatting](../internals/error-system.md#INT-ERROR-FORMATTING)