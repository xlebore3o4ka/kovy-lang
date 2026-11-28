import errors
import ./[args, build, emit, frontend, input, locale, report, targets, version]

const HelpText = """kovy — Kovy compiler front-end

Usage:
  kovy check [options] [file|-]
  kovy emit [options] <file|-> [-o <out.nim>]
  kovy build [options] <file|-> [-o <binary>]
  kovy help
  kovy version

Commands:
  check      Parse and type-check a source file (default input: stdin)
  emit       Write generated Nim and syskovy.nim
  build      Compile a source file to a native binary with Nim
  help       Show this help
  version    Show the compiler version

Options:
  -h, --help             Show this help
  -v, --version          Show the compiler version
  --locale <name>        Locale name (default: en)
  --locale-path <path>   Path to a locale JSON file
  --name <name>          Diagnostic name for stdin (default: <stdin>)
  --no-nimgen            Stop after semantic analysis (check only)
  --json                 Print diagnostics as JSON on stdout (check only)
  -o, --output <path>    Emit/build output; '-' writes Nim to stdout (emit only)

Build options:
  --target <name>        Target alias (default: host)
  --os <name>            Nim target OS
  --cpu <name>           Nim target CPU
  --cc <name>            C compiler
  --release              Build with -d:release
  --debug                Build with --debugger:native
  --nim <path>           Nim compiler (default: nim)
  --nimcache <path>      Nim cache directory
  --keep-nim             Keep generated Nim and the Nim cache
"""

proc usageError(message: string): int =
  stderr.writeLine("error: " & message)
  stderr.writeLine("Try 'kovy --help' for usage.")
  return 2

proc printDiagnostics(analysis: AnalysisResult) =
  for error in analysis.errors:
    stderr.writeLine(analysis.ctx.formatError(analysis.files, error))

proc runCheck(options: CliOptions): int =
  let localePath = resolveLocalePath(options.locale, options.localePath)
  let input = readSource(options.input, options.hasInput, options.name)
  let analysis = analyze(input.source, input.name, localePath,
    runNimgen = not options.noNimgen)

  if options.json:
    stdout.writeLine(renderJson(analysis.ctx, analysis.files, analysis.errors))
    return if analysis.errors.len > 0: 1 else: 0

  if analysis.errors.len > 0:
    printDiagnostics(analysis)
    return 1

  return 0

proc runEmit(options: CliOptions): int =
  let localePath = resolveLocalePath(options.locale, options.localePath)
  let input = readSource(options.input, options.hasInput, options.name)
  let analysis = analyze(input.source, input.name, localePath,
    runNimgen = true, syskovyPath = "./syskovy")

  if analysis.errors.len > 0:
    printDiagnostics(analysis)
    return 1

  let output =
    if options.hasOutput: options.output
    else: defaultOutputName(input)

  if output == "-":
    emitToStdout(analysis)
    stderr.writeLine(
      "warning: generated code imports './syskovy'; place syskovy.nim " &
      "next to the generated file.")
    return 0

  emitToFile(analysis, output)
  return 0

proc runBuild(options: CliOptions): int =
  let localePath = resolveLocalePath(options.locale, options.localePath)
  let input = readSource(options.input, options.hasInput, options.name)
  let analysis = analyze(input.source, input.name, localePath,
    runNimgen = true, syskovyPath = "./syskovy")

  if analysis.errors.len > 0:
    printDiagnostics(analysis)
    return 1

  let output =
    if options.hasOutput: options.output
    else: defaultBinaryName(input)
  let target = resolveTarget(options.target, options.os, options.cpu, options.cc)

  discard buildBinary(analysis, output, target, options.release, options.debug,
    options.nim, options.nimcache, options.keepNim)
  return 0

proc runCommand(options: CliOptions): int =
  case options.command
  of cmdCheck: runCheck(options)
  of cmdEmit: runEmit(options)
  of cmdBuild: runBuild(options)
  else: 0

proc main*(args: seq[string]): int =
  let parsed = parseArgs(args)
  if not parsed.ok:
    return usageError(parsed.error)

  case parsed.options.command
  of cmdHelp:
    stdout.write(HelpText)
    return 0
  of cmdVersion:
    stdout.writeLine("kovy " & KovyVersion)
    return 0
  of cmdCheck, cmdEmit, cmdBuild:
    try:
      return runCommand(parsed.options)
    except LocaleError as error:
      stderr.writeLine("error: " & error.msg)
      stderr.writeLine("Hint: use --locale-path <path> or set KOVY_LOCALE_DIR.")
      return 2
    except InputError as error:
      return usageError(error.msg)
    except CatchableError as error:
      stderr.writeLine("error: " & error.msg)
      return 2
  of cmdNone:
    return usageError("missing command")