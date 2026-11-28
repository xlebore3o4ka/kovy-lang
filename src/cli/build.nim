## Native compilation through the Nim compiler.
import std/[os, osproc, strutils, tempfiles]
import ./[emit, frontend, input, targets]

type
  BuildError* = object of CatchableError

proc defaultBinaryName*(input: SourceInput): string =
  case input.kind
  of inputFile:
    let stem = changeFileExt(input.name, "")
    result = if stem == input.name: input.name & ".out" else: stem
  of inputStdin:
    result = "kovy-out"

proc buildArgs*(generatedPath, output, nimcache: string,
                target: BuildTarget,
                release, debug: bool): seq[string] =
  result = @["c", "--hints:off",
    "--warning:UnusedImport:off", "--out:" & output]
  if nimcache.len > 0:
    result.add "--nimcache:" & nimcache
  if target.os.len > 0:
    result.add "--os:" & target.os
  if target.cpu.len > 0:
    result.add "--cpu:" & target.cpu
  if target.cc.len > 0:
    result.add "--cc:" & target.cc
  if release:
    result.add "-d:release"
  if debug:
    result.add "--debugger:native"
  result.add generatedPath

proc validateOutput(output: string) =
  if output.len == 0:
    raise newException(BuildError, "output path is empty")
  if dirExists(output):
    raise newException(BuildError, "output path is a directory: " & output)
  let dir = output.parentDir
  if dir.len > 0 and not dirExists(dir):
    raise newException(BuildError, "output directory not found: " & dir)

proc runNim(nim: string, args: seq[string]): int =
  try:
    let process = startProcess(nim, args = args,
      options = {poParentStreams, poUsePath})
    try:
      result = waitForExit(process)
    finally:
      close(process)
  except OSError as error:
    # OSError appends its own "Additional info:" line; keep the first line so
    # the build hint stays on one readable message.
    let reason = error.msg.splitLines()[0]
    raise newException(BuildError,
      "cannot run Nim compiler '" & nim & "': " & reason &
      "; install Nim or pass --nim <path>")

proc buildBinary*(analysis: AnalysisResult,
                  output: string,
                  target: BuildTarget,
                  release, debug: bool,
                  nim, nimcache: string,
                  keepNim: bool): string =
  ## Compiles the generated Nim. Returns the kept temporary directory when
  ## `keepNim` is true, otherwise an empty string.
  validateOutput(output)

  let tempDir = createTempDir("kovy-build-", "")
  let generatedPath = tempDir / "main.nim"
  let cache = if nimcache.len > 0: nimcache else: tempDir / "nimcache"

  try:
    emitToFile(analysis, generatedPath)
    let code = runNim(nim,
      buildArgs(generatedPath, output, cache, target, release, debug))
    if code != 0:
      raise newException(BuildError,
        "Nim compilation failed with exit code " & $code)
    if keepNim:
      result = tempDir
  finally:
    if keepNim:
      stderr.writeLine("note: generated Nim kept in " & tempDir)
    else:
      removeDir(tempDir)