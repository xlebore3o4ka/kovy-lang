import std/json
import errors

const SchemaVersion* = 1

proc diagnosticsJson*(ctx: ErrorContext, files: FileTracker,
                      errors: seq[Error]): JsonNode =
  result = newJArray()
  for err in errors:
    let lines = files.fileLines(err.file)
    let sourceLine =
      if err.line - 1 < lines.len: lines[err.line - 1] else: ""

    result.add %*{
      "kind": $err.kind,
      "phase": $err.phase,
      "severity": "error",
      "message": ctx.formatMessage(files, err),
      "addinfo": ctx.formatAddinfo(files, err),
      "line": err.line,
      "column": err.col,
      "length": err.length,
      "sourceLine": sourceLine
    }

proc renderJson*(ctx: ErrorContext, files: FileTracker,
                 errors: seq[Error]): string =
  ## Renders a stable machine-readable diagnostic report. The root object keeps
  ## `schemaVersion` so consumers can reject incompatible output.
  let root = %*{
    "schemaVersion": SchemaVersion,
    "diagnostics": diagnosticsJson(ctx, files, errors)
  }
  result = pretty(root, indent = 2)