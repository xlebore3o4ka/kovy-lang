import parser/[lexer, parser]
import errors, ast
import std/os

let source = """
1 + 2 * 2
"""
let jsonPath = currentSourcePath().parentDir() / "error_locales" / "en.json"
let errCtx = newErrorContext(jsonPath)
let lex = newLexer(source, errCtx)
let prs = newParser(lex, errCtx)

echo prs.parseExpr().toStr()