import std/[json, os, osproc, strutils, unittest]
import errors
import cli/[args, build, emit, frontend, input, locale, report, targets]

const localePath =
  currentSourcePath().parentDir() / ".." / "src" / "error_locales" / "en.json"

suite "cli arguments":
  test "check with a file":
    let parsed = parseArgs(@["check", "main.kovy"])
    check parsed.ok
    check parsed.options.command == cmdCheck
    check parsed.options.input == "main.kovy"
    check parsed.options.hasInput

  test "check with stdin":
    let parsed = parseArgs(@["check", "-"])
    check parsed.ok
    check parsed.options.command == cmdCheck
    check parsed.options.input == "-"
    check parsed.options.hasInput

  test "flags can appear before the command":
    let parsed = parseArgs(@["--locale", "en", "check", "-", "--no-nimgen"])
    check parsed.ok
    check parsed.options.command == cmdCheck
    check parsed.options.locale == "en"
    check parsed.options.hasInput
    check parsed.options.noNimgen

  test "locale path and diagnostic name":
    let parsed = parseArgs(@[
      "check", "--locale-path", "locale.json", "--name", "stdin.kovy",
      "main.kovy"
    ])
    check parsed.ok
    check parsed.options.localePath == "locale.json"
    check parsed.options.name == "stdin.kovy"
    check parsed.options.input == "main.kovy"

  test "help and version flags":
    let help = parseArgs(@["--help"])
    check help.ok
    check help.options.command == cmdHelp

    let version = parseArgs(@["--version"])
    check version.ok
    check version.options.command == cmdVersion

  test "help and version commands":
    check parseArgs(@["help"]).options.command == cmdHelp
    check parseArgs(@["version"]).options.command == cmdVersion

  test "missing command is an error":
    let parsed = parseArgs(@[])
    check not parsed.ok
    check "missing command" in parsed.error

  test "unknown command is an error":
    let parsed = parseArgs(@["lint"])
    check not parsed.ok
    check "unknown command" in parsed.error

  test "only one input file is supported":
    let parsed = parseArgs(@["check", "a.kovy", "b.kovy"])
    check not parsed.ok
    check "only one input file" in parsed.error

  test "locale and locale-path cannot be combined":
    let parsed = parseArgs(@[
      "check", "--locale", "en", "--locale-path", "locale.json"
    ])
    check not parsed.ok
    check "cannot be used together" in parsed.error

  test "unknown option is an error":
    let parsed = parseArgs(@["check", "--wat"])
    check not parsed.ok
    check "unknown option" in parsed.error

  test "no-nimgen does not take a value":
    let parsed = parseArgs(@["check", "--no-nimgen=yes"])
    check not parsed.ok
    check "does not take a value" in parsed.error

suite "cli locale":
  test "explicit locale path":
    check resolveLocalePath("en", localePath) == localePath

  test "default locale is found in the repository":
    let path = resolveLocalePath("en", "")
    check fileExists(path)

  test "missing locale path is reported":
    expect LocaleError:
      discard resolveLocalePath("en", "/definitely/missing/locale.json")

suite "cli input":
  test "reads a file and keeps its name":
    let path = getTempDir() / "kovy-cli-input.kovy"
    writeFile(path, "int x = 1\n")
    defer: removeFile(path)

    let input = readSource(path, hasInput = true)
    check input.kind == inputFile
    check input.name == path
    check input.source == "int x = 1\n"

  test "name override is used for a file":
    let path = getTempDir() / "kovy-cli-name.kovy"
    writeFile(path, "int x = 1\n")
    defer: removeFile(path)

    let input = readSource(path, hasInput = true, nameOverride = "shown.kovy")
    check input.name == "shown.kovy"

  test "missing file is reported":
    expect InputError:
      discard readSource("/definitely/missing/input.kovy", hasInput = true)

suite "cli frontend":
  test "valid source passes and generates Nim":
    let analysis = analyze("int x = 1\n", "<test>", localePath)
    check analysis.errors.len == 0
    check analysis.generated.len > 0

  test "lexer errors are reported":
    let analysis = analyze("int x = @\n", "<test>", localePath)
    check analysis.errors.len == 1
    check analysis.errors[0].kind == errUnknownCharacter
    check analysis.generated.len == 0

  test "semantic errors are reported":
    let analysis = analyze("int x = missing\n", "<test>", localePath)
    check analysis.errors.len == 1
    check analysis.errors[0].kind == errUnknownSymbol
    check analysis.generated.len == 0

  test "nimgen can be skipped":
    let analysis = analyze("int x = 1\n", "<test>", localePath,
      runNimgen = false)
    check analysis.errors.len == 0
    check analysis.generated.len == 0

  test "nimgen errors are reported":
    let analysis = analyze("void* p\n", "<test>", localePath)
    check analysis.errors.len == 1
    check analysis.errors[0].kind == errNonConcreteType

suite "cli json report":
  test "json flag is parsed":
    let parsed = parseArgs(@["check", "--json", "-"])
    check parsed.ok
    check parsed.options.json
    check parsed.options.hasInput

  test "json flag does not take a value":
    let parsed = parseArgs(@["check", "--json=yes"])
    check not parsed.ok
    check "does not take a value" in parsed.error

  test "clean source has an empty diagnostics array":
    let analysis = analyze("int x = 1\n", "<test>", localePath)
    const emptyReport = "{\n  \"schemaVersion\": 1,\n  \"diagnostics\": []\n}"
    check renderJson(analysis.ctx, analysis.files, analysis.errors) ==
      emptyReport

  test "diagnostic fields and schema version":
    let analysis = analyze("int x = missing\n", "<test>", localePath)
    let rendered = renderJson(analysis.ctx, analysis.files, analysis.errors)
    let root = parseJson(rendered)

    check root["schemaVersion"].getInt == 1
    let diagnostics = root["diagnostics"]
    check diagnostics.len == 1

    let diagnostic = diagnostics[0]
    check diagnostic["kind"].getStr == "errUnknownSymbol"
    check diagnostic["phase"].getStr == "sema"
    check diagnostic["severity"].getStr == "error"
    check diagnostic["message"].getStr == "Unknown symbol: 'missing'"
    check diagnostic["addinfo"].getStr == ""
    check diagnostic["line"].getInt == 1
    check diagnostic["column"].getInt == 9
    check diagnostic["length"].getInt == 7
    check diagnostic["sourceLine"].getStr == "int x = missing"

  test "phases are reported per pipeline stage":
    let lexer = analyze("int x = @\n", "<test>", localePath)
    check parseJson(renderJson(lexer.ctx, lexer.files,
      lexer.errors))["diagnostics"][0]["phase"].getStr == "lexer"

    let parser = analyze("int x = (1\n", "<test>", localePath)
    check parseJson(renderJson(parser.ctx, parser.files,
      parser.errors))["diagnostics"][0]["phase"].getStr == "parser"

    let sema = analyze("int x = missing\n", "<test>", localePath)
    check parseJson(renderJson(sema.ctx, sema.files,
      sema.errors))["diagnostics"][0]["phase"].getStr == "sema"

    let finalize = analyze("int f(int a)\nint z = 1\n", "<test>", localePath)
    check parseJson(renderJson(finalize.ctx, finalize.files,
      finalize.errors))["diagnostics"][0]["phase"].getStr == "finalize"

    let nimgen = analyze("void* p\n", "<test>", localePath)
    check parseJson(renderJson(nimgen.ctx, nimgen.files,
      nimgen.errors))["diagnostics"][0]["phase"].getStr == "nimgen"

  test "json escapes quotes in messages and source lines":
    let analysis = analyze("int x = \"\n", "<test>", localePath)
    let rendered = renderJson(analysis.ctx, analysis.files, analysis.errors)

    check rendered.contains("\\\"")

    let diagnostic = parseJson(rendered)["diagnostics"][0]
    check diagnostic["sourceLine"].getStr == "int x = \""
    check diagnostic["message"].getStr.contains("\"")

suite "cli emit arguments":
  test "emit with a separate output":
    let parsed = parseArgs(@["emit", "main.kovy", "-o", "out.nim"])
    check parsed.ok
    check parsed.options.command == cmdEmit
    check parsed.options.input == "main.kovy"
    check parsed.options.hasInput
    check parsed.options.hasOutput
    check parsed.options.output == "out.nim"

  test "emit output can use ':' or '='":
    check parseArgs(@["emit", "a.kovy", "-o:out.nim"]).options.output == "out.nim"
    check parseArgs(@["emit", "a.kovy", "-o=out.nim"]).options.output == "out.nim"

  test "emit output to stdout":
    let parsed = parseArgs(@["emit", "a.kovy", "-o", "-"])
    check parsed.ok
    check parsed.options.output == "-"

  test "emit output long option":
    let parsed = parseArgs(@["emit", "a.kovy", "--output", "out.nim"])
    check parsed.ok
    check parsed.options.output == "out.nim"

  test "output requires a value":
    let parsed = parseArgs(@["emit", "a.kovy", "-o"])
    check not parsed.ok
    check "requires a value" in parsed.error

  test "output is only valid for emit":
    let parsed = parseArgs(@["check", "a.kovy", "-o", "out.nim"])
    check not parsed.ok
    check "only valid for 'emit'" in parsed.error

  test "json and no-nimgen are only valid for check":
    let withJson = parseArgs(@["emit", "a.kovy", "--json"])
    check not withJson.ok
    check "only valid for 'check'" in withJson.error

    let withNoNimgen = parseArgs(@["emit", "a.kovy", "--no-nimgen"])
    check not withNoNimgen.ok
    check "only valid for 'check'" in withNoNimgen.error

suite "cli emit output":
  test "default output for a file input":
    let path = getTempDir() / "kovy-emit-default.kovy"
    writeFile(path, "int x = 1\n")
    defer: removeFile(path)

    let input = readSource(path, hasInput = true)
    check defaultOutputName(input) == changeFileExt(path, "nim")

  test "default output for stdin":
    let input = SourceInput(source: "", name: "<stdin>", kind: inputStdin)
    check defaultOutputName(input) == "kovy-out.nim"

  test "generated code imports the adjacent runtime":
    let analysis = analyze("int x = 1\n", "<test>", localePath,
      syskovyPath = "./syskovy")
    check analysis.errors.len == 0
    check analysis.generated.contains("import \"./syskovy\"")

  test "emit writes nim and runtime files":
    let dir = getTempDir() / "kovy-emit-output"
    if dirExists(dir):
      removeDir(dir)
    createDir(dir)
    defer: removeDir(dir)

    let analysis = analyze("int x = 1\n", "main.kovy", localePath,
      syskovyPath = "./syskovy")
    let output = dir / "main.nim"
    emitToFile(analysis, output)

    check fileExists(output)
    check fileExists(dir / "syskovy.nim")
    check readFile(output).contains("import \"./syskovy\"")
    check readFile(dir / "syskovy.nim").contains("proc `+`")

  test "missing output directory is reported":
    let analysis = analyze("int x = 1\n", "main.kovy", localePath,
      syskovyPath = "./syskovy")
    expect IOError:
      emitToFile(analysis, getTempDir() / "kovy-missing-dir" / "main.nim")

suite "cli build arguments":
  test "build with defaults":
    let parsed = parseArgs(@["build", "main.kovy"])
    check parsed.ok
    check parsed.options.command == cmdBuild
    check parsed.options.input == "main.kovy"
    check parsed.options.target == "host"
    check parsed.options.nim == "nim"
    check not parsed.options.release
    check not parsed.options.debug
    check not parsed.options.keepNim

  test "build flags are parsed":
    let parsed = parseArgs(@[
      "build", "main.kovy", "-o", "prog",
      "--target", "windows-amd64", "--release", "--keep-nim",
      "--nim", "/opt/nim/bin/nim", "--nimcache", "cache"
    ])
    check parsed.ok
    check parsed.options.output == "prog"
    check parsed.options.target == "windows-amd64"
    check parsed.options.release
    check parsed.options.keepNim
    check parsed.options.nim == "/opt/nim/bin/nim"
    check parsed.options.nimcache == "cache"

  test "raw target flags are parsed":
    let parsed = parseArgs(@[
      "build", "main.kovy", "--os", "linux", "--cpu", "arm64", "--cc", "clang"
    ])
    check parsed.ok
    check parsed.options.os == "linux"
    check parsed.options.cpu == "arm64"
    check parsed.options.cc == "clang"

  test "build options are only valid for build":
    let forCheck = parseArgs(@["check", "main.kovy", "--target", "host"])
    check not forCheck.ok
    check "only valid for 'build'" in forCheck.error

    let forEmit = parseArgs(@["emit", "main.kovy", "--release"])
    check not forEmit.ok
    check "only valid for 'build'" in forEmit.error

  test "release and debug are mutually exclusive":
    let parsed = parseArgs(@["build", "main.kovy", "--release", "--debug"])
    check not parsed.ok
    check "cannot be used together" in parsed.error

  test "build rejects stdout output":
    let parsed = parseArgs(@["build", "main.kovy", "-o", "-"])
    check not parsed.ok
    check "'-o -' is not valid for 'build'" in parsed.error

  test "json and no-nimgen are only valid for check":
    let withJson = parseArgs(@["build", "main.kovy", "--json"])
    check not withJson.ok
    check "only valid for 'check'" in withJson.error

    let withNoNimgen = parseArgs(@["build", "main.kovy", "--no-nimgen"])
    check not withNoNimgen.ok
    check "only valid for 'check'" in withNoNimgen.error

suite "cli build targets":
  test "host target has no explicit flags":
    let target = resolveTarget("host", "", "", "")
    check target.os.len == 0
    check target.cpu.len == 0
    check target.cc.len == 0

  test "curated aliases map to Nim OS and CPU":
    let target = resolveTarget("linux-arm64", "", "", "")
    check target.os == "linux"
    check target.cpu == "arm64"

    let macos = resolveTarget("macos-arm64", "", "", "")
    check macos.os == "macosx"
    check macos.cpu == "arm64"

  test "raw flags override a preset":
    let target = resolveTarget("linux-amd64", "windows", "i386", "gcc")
    check target.os == "windows"
    check target.cpu == "i386"
    check target.cc == "gcc"

  test "unknown target lists known aliases":
    expect TargetError:
      discard resolveTarget("plan9-amd64", "", "", "")
    try:
      discard resolveTarget("plan9-amd64", "", "", "")
      check false
    except TargetError as error:
      check "unknown target 'plan9-amd64'" in error.msg
      check "linux-amd64" in error.msg

suite "cli build args":
  test "build args suppress the unused runtime import":
    let args = buildArgs("main.nim", "prog", "cache",
      BuildTarget(os: "linux", cpu: "amd64", cc: "gcc"), false, false)
    check args[0] == "c"
    check "--hints:off" in args
    check "--warning:UnusedImport:off" in args
    check "--out:prog" in args
    check "--nimcache:cache" in args
    check "--os:linux" in args
    check "--cpu:amd64" in args
    check "--cc:gcc" in args
    check "-d:release" notin args
    check "--debugger:native" notin args
    check args[^1] == "main.nim"

  test "build args add release or debug":
    let release = buildArgs("main.nim", "prog", "", BuildTarget(), true, false)
    check "-d:release" in release
    check "--debugger:native" notin release

    let debug = buildArgs("main.nim", "prog", "", BuildTarget(), false, true)
    check "-d:release" notin debug
    check "--debugger:native" in debug

suite "cli build names":
  test "default binary for a file input":
    let input = SourceInput(source: "", name: "src/main.kovy", kind: inputFile)
    check defaultBinaryName(input) == "src/main"

  test "default binary for an extensionless input":
    let input = SourceInput(source: "", name: "main", kind: inputFile)
    check defaultBinaryName(input) == "main.out"

  test "default binary for stdin":
    let input = SourceInput(source: "", name: "<stdin>", kind: inputStdin)
    check defaultBinaryName(input) == "kovy-out"

suite "cli build integration":
  test "builds and runs a program":
    let dir = getTempDir() / "kovy-build-cli"
    if dirExists(dir):
      removeDir(dir)
    createDir(dir)
    defer: removeDir(dir)

    let analysis = analyze("int x = 1\n", "main.kovy", localePath,
      syskovyPath = "./syskovy")
    check analysis.errors.len == 0

    let output = dir / "ok"
    discard buildBinary(analysis, output, resolveTarget("host", "", "", ""),
      false, false, "nim", "", false)

    let binary = if fileExists(output): output else: output & ".exe"
    check fileExists(binary)
    let run = execCmdEx(binary)
    check run.exitCode == 0

  test "missing Nim compiler is reported clearly":
    let analysis = analyze("int x = 1\n", "main.kovy", localePath,
      syskovyPath = "./syskovy")
    check analysis.errors.len == 0

    var message = ""
    try:
      discard buildBinary(analysis, getTempDir() / "kovy-missing-nim-bin",
        BuildTarget(), false, false,
        getTempDir() / "kovy-no-such-nim", "", false)
      check false
    except BuildError as error:
      message = error.msg

    check "cannot run Nim compiler" in message
    check "install Nim or pass --nim" in message
    check "Additional info" notin message