import std/[os, terminal]

type
  InputKind* = enum
    inputFile, inputStdin

  SourceInput* = object
    source*: string
    name*: string
    kind*: InputKind

  InputError* = object of CatchableError

proc readSource*(input: string, hasInput: bool,
                 nameOverride: string = ""): SourceInput =
  if hasInput and input != "-":
    if not fileExists(input):
      raise newException(InputError, "input file not found: " & input)
    if dirExists(input):
      raise newException(InputError, "input path is a directory: " & input)

    result.source = readFile(input)
    result.name = if nameOverride.len > 0: nameOverride else: input
    result.kind = inputFile
    return

  if not hasInput and isatty(stdin):
    raise newException(InputError,
      "no input file; pass a file, '-', or pipe source to stdin")

  result.source = stdin.readAll()
  result.name = if nameOverride.len > 0: nameOverride else: "<stdin>"
  result.kind = inputStdin