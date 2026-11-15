import parser/[lexer, parser]
import errors
import visitors/[sema, nimgen]
import std/[os, tables]

let source = """
int mut a = 0
if 1 == 1:
  int mut b = 10
  a = 1
elif 2 == 2:
  a = 2
else:
  a = 3
b = 3
"""

let jsonPath = currentSourcePath().parentDir() / "error_locales" / "en.json"
let errCtx = newErrorContext(jsonPath)

block process:
  block successfulness:
    let lex = newLexer(source, errCtx)

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
    echo $err.file & "(" & $err.line & "," & $err.col & ") [" & $err.kind & "]"
    let data = errCtx.placeholders[$err.kind]
    echo data.message
    echo data.addinfo
    echo err.placeholders
