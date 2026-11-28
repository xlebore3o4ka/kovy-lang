## Output helpers for `kovy emit`.
import std/[os, strutils]
import ./[embedded, frontend, input]

proc defaultOutputName*(input: SourceInput): string =
  case input.kind
  of inputFile:
    changeFileExt(input.name, "nim")
  of inputStdin:
    "kovy-out.nim"

proc withTrailingNewline(text: string): string =
  if text.endsWith("\n"): text else: text & "\n"

proc emitToStdout*(analysis: AnalysisResult) =
  stdout.write(withTrailingNewline(analysis.generated))

proc emitToFile*(analysis: AnalysisResult, output: string) =
  ## Writes generated Nim to `output` and the embedded runtime next to it.
  let dir = output.parentDir
  if dir.len > 0 and not dirExists(dir):
    raise newException(IOError, "output directory not found: " & dir)

  writeFile(output, withTrailingNewline(analysis.generated))

  let runtimePath = if dir.len > 0: dir / "syskovy.nim" else: "syskovy.nim"
  writeFile(runtimePath, withTrailingNewline(SyskovySource))