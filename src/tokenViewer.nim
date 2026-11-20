import parser/[lexer, tokens]
import errors
import std/[os]

let source = """
int mut x; int mut i
while i < 100:
  i = i + 1
  if i > 27 and i < 65:
    continue
  x = x + i
  if x * i > 10000:
    break
"""

let errCtx = newErrorContext(currentSourcePath().parentDir() / "error_locales" / "en.json")
let fileTracker = FileTracker()

let lex = newLexer(source, errCtx, fileTracker.newFile("<string>", source))

while lex.peekTok().kind != tkEOF:
  let t = lex.nextTok()
  if t.kind == tkIndent:
    stdout.write("(indent) ")
  elif t.kind == tkDedent:
    stdout.write("(dedent) ")
  else:
    stdout.write("(", t.lexeme, ") ")
  if t.kind in {tkEos, tkIndent, tkDedent}: echo ""

echo "(eof)"