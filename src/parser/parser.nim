import lexer, tokens
import ../[errors, ast]

type
  Parser* = ref object
    lexer*: Lexer
    errors*: ErrorContext

proc newParser*(lexer: Lexer, errors: ErrorContext): Parser =
  Parser(lexer: lexer, errors: errors)

proc nextToken*(self: Parser): Token =
  self.lexer.nextTok()

proc peekToken*(self: Parser): Token =
  self.lexer.peekTok()

proc newError*(self: Parser, kind: ErrorKind, tok: Token, placeholders: varargs[string, `$`]) =
  self.errors.add newError(kind, tok.file, tok.line, tok.col, tok.lexeme.len, @placeholders)
  while true:
    let t = self.nextToken()
    if t.kind in {tkEOS, tkEOF}:
      break

proc parsePrimary*(self: Parser): Expr =
  let t = self.nextToken()

  if t.kind == tkNumber:
    return newNumber(t)

  self.newError(errNotExpression, t, t.mean())
  return t.newInvalid()

proc parseUnary*(self: Parser): Expr =
  if self.peekToken().kind in {tkPlus, tkMinus}:
    return self.nextToken().newUnary(self.parseUnary())
  return self.parsePrimary()

proc parseMulDiv*(self: Parser): Expr =
  result = self.parseUnary()

  while self.peekToken().kind in {tkStar, tkSlash}:
    result = self.nextToken().newBinary(result, self.parseUnary())

proc parseAddSub*(self: Parser): Expr =
  result = self.parseMulDiv()

  while self.peekToken().kind in {tkPlus, tkMinus}:
    result = self.nextToken().newBinary(result, self.parseMulDiv())

proc parseExpr*(self: Parser): Expr =
  self.parseAddSub()