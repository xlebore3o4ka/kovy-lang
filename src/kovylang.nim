import parser/[lexer, tokens], errors, std/os

let source = "42 + 3 * (1 - 5)"
let jsonPath = currentSourcePath().parentDir() / "error_locales" / "en.json"
var lex = Lexer(source: source, errors: newErrorContext(jsonPath))

while true:
  let tok = lex.nextTok()
  echo tok.kind, " ", tok.lexeme
  if tok.kind == tkEOF:
    break