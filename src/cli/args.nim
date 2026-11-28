import std/parseopt

type
  CommandKind* = enum
    cmdNone, cmdCheck, cmdEmit, cmdBuild, cmdHelp, cmdVersion

  CliOptions* = object
    command*: CommandKind
    input*: string
    hasInput*: bool
    output*: string
    hasOutput*: bool
    name*: string
    locale*: string
    localePath*: string
    noNimgen*: bool
    json*: bool
    showHelp*: bool
    showVersion*: bool

    target*: string
    os*: string
    cpu*: string
    cc*: string
    release*: bool
    debug*: bool
    nim*: string
    nimcache*: string
    keepNim*: bool

  ParseResult* = object
    ok*: bool
    error*: string
    options*: CliOptions

proc fail(result: var ParseResult, message: string) =
  result.ok = false
  result.error = message

proc normalizeShortOptions(args: seq[string]): seq[string] =
  # `parseopt` requires `-o:value` or `-o=value` for short options with a
  # value. Accept the conventional `-o value` by joining the pair.
  var i = 0
  var afterTerminator = false
  while i < args.len:
    if afterTerminator:
      result.add args[i]
      inc i
    elif args[i] == "--":
      result.add args[i]
      afterTerminator = true
      inc i
    elif args[i] == "-o" and i + 1 < args.len:
      result.add "-o:" & args[i + 1]
      i += 2
    else:
      result.add args[i]
      inc i

proc parseArgs*(args: seq[string]): ParseResult =
  result.ok = true
  result.options.locale = "en"
  result.options.target = "host"
  result.options.nim = "nim"

  var positionals: seq[string]
  var localeSet = false
  var localePathSet = false
  var outputSet = false
  var buildOptionSet = false

  # `longNoVal` enables `--flag value` in addition to `--flag=value`. Options
  # that do not take a value must be listed here.
  var parser = initOptParser(normalizeShortOptions(args),
    shortNoVal = {'h', 'v'},
    longNoVal = @["help", "version", "no-nimgen", "json",
      "release", "debug", "keep-nim"])

  while true:
    parser.next()
    case parser.kind
    of cmdEnd:
      break

    of cmdShortOption:
      if parser.key.len == 0:
        # A bare `-` is the stdin input, not an option.
        positionals.add "-"
      elif parser.key == "h":
        result.options.showHelp = true
      elif parser.key == "v":
        result.options.showVersion = true
      elif parser.key == "o":
        if parser.val.len == 0:
          result.fail("option '-o' requires a value")
          return
        result.options.output = parser.val
        result.options.hasOutput = true
        outputSet = true
      else:
        result.fail("unknown option '-" & parser.key & "'")
        return

    of cmdLongOption:
      let key = parser.key
      let value = parser.val

      case key
      of "help":
        result.options.showHelp = true
      of "version":
        result.options.showVersion = true
      of "no-nimgen":
        if value.len > 0:
          result.fail("option '--no-nimgen' does not take a value")
          return
        result.options.noNimgen = true
      of "json":
        if value.len > 0:
          result.fail("option '--json' does not take a value")
          return
        result.options.json = true
      of "locale":
        if value.len == 0:
          result.fail("option '--locale' requires a value")
          return
        result.options.locale = value
        localeSet = true
      of "locale-path":
        if value.len == 0:
          result.fail("option '--locale-path' requires a value")
          return
        result.options.localePath = value
        localePathSet = true
      of "name":
        if value.len == 0:
          result.fail("option '--name' requires a value")
          return
        result.options.name = value
      of "output":
        if value.len == 0:
          result.fail("option '--output' requires a value")
          return
        result.options.output = value
        result.options.hasOutput = true
        outputSet = true
      of "target":
        if value.len == 0:
          result.fail("option '--target' requires a value")
          return
        result.options.target = value
        buildOptionSet = true
      of "os":
        if value.len == 0:
          result.fail("option '--os' requires a value")
          return
        result.options.os = value
        buildOptionSet = true
      of "cpu":
        if value.len == 0:
          result.fail("option '--cpu' requires a value")
          return
        result.options.cpu = value
        buildOptionSet = true
      of "cc":
        if value.len == 0:
          result.fail("option '--cc' requires a value")
          return
        result.options.cc = value
        buildOptionSet = true
      of "release":
        if value.len > 0:
          result.fail("option '--release' does not take a value")
          return
        result.options.release = true
        buildOptionSet = true
      of "debug":
        if value.len > 0:
          result.fail("option '--debug' does not take a value")
          return
        result.options.debug = true
        buildOptionSet = true
      of "nim":
        if value.len == 0:
          result.fail("option '--nim' requires a value")
          return
        result.options.nim = value
        buildOptionSet = true
      of "nimcache":
        if value.len == 0:
          result.fail("option '--nimcache' requires a value")
          return
        result.options.nimcache = value
        buildOptionSet = true
      of "keep-nim":
        if value.len > 0:
          result.fail("option '--keep-nim' does not take a value")
          return
        result.options.keepNim = true
        buildOptionSet = true
      of "":
        # `--` terminates option parsing.
        for argument in parser.remainingArgs:
          positionals.add argument
        break
      else:
        result.fail("unknown option '--" & key & "'")
        return

    of cmdArgument:
      positionals.add parser.key

  if localeSet and localePathSet:
    result.fail("options '--locale' and '--locale-path' cannot be used together")
    return

  if result.options.showHelp:
    result.options.command = cmdHelp
  elif result.options.showVersion:
    result.options.command = cmdVersion
  else:
    if positionals.len == 0:
      result.fail("missing command")
      return

    case positionals[0]
    of "check":
      result.options.command = cmdCheck
    of "emit":
      result.options.command = cmdEmit
    of "build":
      result.options.command = cmdBuild
    of "help":
      result.options.command = cmdHelp
    of "version":
      result.options.command = cmdVersion
    else:
      result.fail("unknown command '" & positionals[0] & "'")
      return

    if positionals.len > 1:
      result.options.input = positionals[1]
      result.options.hasInput = true

    if positionals.len > 2:
      result.fail("only one input file is supported")
      return

  case result.options.command
  of cmdCheck:
    if outputSet:
      result.fail("option '-o/--output' is only valid for 'emit' and 'build'")
    elif buildOptionSet:
      result.fail("build options are only valid for 'build'")
  of cmdEmit:
    if buildOptionSet:
      result.fail("build options are only valid for 'build'")
    elif result.options.json:
      result.fail("option '--json' is only valid for 'check'")
    elif result.options.noNimgen:
      result.fail("option '--no-nimgen' is only valid for 'check'")
  of cmdBuild:
    if result.options.json:
      result.fail("option '--json' is only valid for 'check'")
    elif result.options.noNimgen:
      result.fail("option '--no-nimgen' is only valid for 'check'")
    elif result.options.release and result.options.debug:
      result.fail("options '--release' and '--debug' cannot be used together")
    elif outputSet and result.options.output == "-":
      result.fail("option '-o -' is not valid for 'build'")
  else:
    discard