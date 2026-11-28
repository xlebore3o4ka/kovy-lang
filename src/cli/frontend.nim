import parser/[lexer, parser]
import errors
import visitors/[sema, nimgen]

type
  AnalysisResult* = object
    errors*: seq[Error]
    generated*: string
    files*: FileTracker
    ctx*: ErrorContext

proc markPhases(ctx: ErrorContext, first: int, phase: ErrorPhase) =
  for i in first ..< ctx.errors.len:
    ctx.errors[i].phase = phase

proc markParsePhases(ctx: ErrorContext, first: int) =
  # Lexing is interleaved with parsing, so the phase is derived from the kind.
  for i in first ..< ctx.errors.len:
    case ctx.errors[i].kind
    of errUnknownCharacter, errIndent:
      ctx.errors[i].phase = phaseLexer
    else:
      ctx.errors[i].phase = phaseParser

proc analyze*(source, name, localePath: string,
              runNimgen = true,
              syskovyPath = ""): AnalysisResult =
  result.ctx = newErrorContext(localePath)
  result.files = FileTracker()

  let file = result.files.newFile(name, source)
  let lexer = newLexer(source, result.ctx, file)

  let parseStart = result.ctx.errors.len
  let tree = newParser(lexer, result.ctx).parse()
  markParsePhases(result.ctx, parseStart)

  if not result.ctx.hasErrors():
    let sema = newSema(result.ctx, result.files)

    let semaStart = result.ctx.errors.len
    discard sema.visit(tree)
    markPhases(result.ctx, semaStart, phaseSema)

    let finalizeStart = result.ctx.errors.len
    sema.finalize()
    markPhases(result.ctx, finalizeStart, phaseFinalize)

  if runNimgen and not result.ctx.hasErrors():
    let nimgenStart = result.ctx.errors.len
    result.generated = newNimgen(result.ctx, syskovyPath).emit(tree)
    markPhases(result.ctx, nimgenStart, phaseNimgen)

  result.errors = result.ctx.errors