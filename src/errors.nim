import std/[json, tables, os]

type
  ErrorKind* = enum
    errUnknownCharacter, errNotExpression

  Error* = object
    kind*: ErrorKind
    placeholders*: seq[string]
    length*: Natural
    col*: Positive = 1
    line*: Positive = 1
    file*: Natural

  ErrorContext* = ref object
    errors*: seq[Error]
    placeholders*: Table[string, tuple[message: string, addinfo: string]]

  LocaleLoadError* = object of CatchableError

proc newError*(kind: ErrorKind, file: Natural, line, col: Positive,
    length: Natural, placeholders: varargs[string, `$`]): Error =
  Error(kind: kind, placeholders: @placeholders, file: file, line: line, col: col, length: length)

proc newError*(kind: ErrorKind, file: Natural, line, col: Positive,
    length: Natural, placeholders: seq[string]): Error =
  Error(kind: kind, placeholders: placeholders, file: file, line: line, col: col, length: length)

proc newErrorContext*(jsonPath: string): ErrorContext =
  if fileExists(jsonPath):
    let jsonContent = readFile(jsonPath)
    let jsonData = parseJson(jsonContent)
    var placeholdersTable = initTable[string, tuple[message: string, addinfo: string]]()
    for key, value in jsonData.pairs:
      placeholdersTable[key] = (message: value["message"].str, addinfo: value["addinfo"].str)
    return ErrorContext(errors: @[], placeholders: placeholdersTable)

  else:
    raise newException(LocaleLoadError, "can't open file '" & jsonPath & "': No sush file or directory")

proc add*(ctx: ErrorContext, error: Error) =
  ctx.errors.add(error)