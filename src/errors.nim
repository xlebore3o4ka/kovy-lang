import std/[json, tables, os, strutils]

type
  ErrorKind* = enum
    errUnknownCharacter, errSyntax, errTypeSyntax, errUnknownSymbol
    errIndent

    errExpressionExpected, errStatementExpected

    errDoesNotFit, errBinaryMismatch, errUnaryMismatch

    errRedeclaration, errImmutableAssignment

    errContextScope

    errIllformedArgument, errVoidReturnValue
    errReturnValueExpected

    errNotCallable, errWrongArity, errArgMismatch

    errReturnDanglingMutable
    errImmutableReturn
    errNotAllPathsReturn
    errUnreachableCode

    errForwardOutsideGlobal, errFuncSignatureMismatch
    errFuncRedefinition, errUnresolvedForward
    errOverloadByReturnType, errAmbiguousCall, errNoMatchingOverload
    errEmptyFunctionBody
    errDefaultForbidden

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

  FileTracker* = ref object
    nextFile: Natural
    interns: seq[string]
    lines: seq[seq[string]]

proc newFile*(ft: FileTracker, name: string, source: string): Natural =
  result = ft.nextFile
  ft.interns.add name
  ft.lines.add source.splitLines()
  ft.nextFile.inc()
  return

proc uninternFile*(ft: FileTracker, file: Natural): string =
  ft.interns[file]

proc fileLines*(ft: FileTracker, file: Natural): seq[string] =
  ft.lines[file]

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
      if value.kind != JObject:
        continue
      let message = value{"message"}
      if message == nil:
        continue
      let addinfo = value{"addinfo"}
      placeholdersTable[key] = (message: message.getStr,
                              addinfo: if addinfo == nil: "" else: addinfo.getStr)
    return ErrorContext(errors: @[], placeholders: placeholdersTable)

  else:
    raise newException(LocaleLoadError, "can't open file '" & jsonPath & "': No sush file or directory")

proc add*(ctx: ErrorContext, error: Error) =
  ctx.errors.add(error)

proc hasErrors*(ctx: ErrorContext): bool =
  ctx.errors.len > 0

proc formatPlaceholders(ctx: ErrorContext, ft: FileTracker, tmpl: string,
                      placeholders: seq[string]): string =
  result = ""
  var i = 0
  while i < tmpl.len:
    if tmpl[i] == '@':
      var j = i + 1
      var modifier = ""
      while j < tmpl.len and tmpl[j] notin Digits:
        modifier.add tmpl[j]
        inc j
      var idx = 0
      while j < tmpl.len and tmpl[j] in Digits:
        idx = idx * 10 + (ord(tmpl[j]) - ord('0'))
        inc j
      if idx < placeholders.len:
        let val = placeholders[idx]
        case modifier
        of "q": result.add "'" & val & "'"
        of "c": result.add "`" & val & "`"
        of "f": result.add ft.uninternFile(parseInt(val))
        else:   result.add val
      i = j
    else:
      result.add tmpl[i]
      inc i

proc formatError*(ctx: ErrorContext, ft: FileTracker, err: Error): string =
  let data = ctx.placeholders[$err.kind]
  let path = ft.uninternFile(err.file)
  let lineText = if err.line - 1 < ft.fileLines(err.file).len: ft.fileLines(err.file)[err.line - 1] else: ""

  let marker = if err.length < 2: "^" else: "~"

  result.add path & "(" & $err.col & "," & $err.line & ") [" & $err.kind & "]\n"
  result.add "  |\n"
  result.add "  | " & lineText & "\n"
  result.add "  V " & " ".repeat(err.col - 1) & marker.repeat(err.length) & "\n"
  result.add ctx.formatPlaceholders(ft, data.message, err.placeholders) & "\n"
  if data.addinfo != "":
    result.add "  " & ctx.formatPlaceholders(ft, data.addinfo, err.placeholders)