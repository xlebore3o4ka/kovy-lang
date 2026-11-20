import parser/[lexer, parser]
import errors
import visitors/[sema, nimgen]
import std/[os]

let source = """
int a(bool b):
  if b:
    this()
    code()
    has()
    no()
    return_()
  else:
    return 1
"""

let errCtx = newErrorContext(currentSourcePath().parentDir() / "error_locales" / "en.json")
let fileTracker = FileTracker()

block process:
  block successfulness:
    let lex = newLexer(source, errCtx, fileTracker.newFile("<string>", source))

    if errCtx.hasErrors():
      break successfulness

    let prs = newParser(lex, errCtx)
    let codeAst = prs.parse()

    if errCtx.hasErrors():
      break successfulness

    let semantics = newSema(errCtx)
    discard semantics.visit(codeAst)
    
    if errCtx.hasErrors():
      break successfulness

    # Done.

    let ng = newNimgen()
    echo ng.emit(codeAst)

    break process

  for err in errCtx.errors:
    echo errCtx.formatError(fileTracker, err)
