import parser/[lexer, parser]
import errors
import visitors/[sema, nimgen]
import std/[os]

let source = """
int a(int a):
  return a

int a(int mut a):
  return a

int b = a(10)
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

    let semantics = newSema(errCtx, fileTracker)
    discard semantics.visit(codeAst)
    semantics.finalize()
    
    if errCtx.hasErrors():
      break successfulness

    # Done.

    let ng = newNimgen()
    echo ng.emit(codeAst)

    break process

  for err in errCtx.errors:
    echo errCtx.formatError(fileTracker, err)
