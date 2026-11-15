import lexer, tokens
import ../[errors, ast, types]
import std/[macros]

type
  Parser* = ref object
    lexer*: Lexer
    errors*: ErrorContext

  ExpectedToken* = object
    case isExpected*: bool
    of true: expected*: Token
    of false: unexpected*: Token

proc expectedToken*(t: Token): ExpectedToken =
  ExpectedToken(isExpected: true, expected: t)

proc unexpectedToken*(t: Token): ExpectedToken =
  ExpectedToken(isExpected: false, unexpected: t)

macro ifUnexpected*(t: ExpectedToken, body: untyped): untyped =
  let tmp = genSym(nskLet, "tmp")
  result = quote do:
    let `tmp` = `t`
    if `tmp`.isExpected: `tmp`.expected
    else:
      let it {.inject, used.} = `tmp`.unexpected
      `body`

proc newParser*(lexer: Lexer, errors: ErrorContext): Parser =
  Parser(lexer: lexer, errors: errors)

proc nextToken(self: Parser): Token =
  self.lexer.nextTok()

proc peekToken(self: Parser): Token =
  self.lexer.peekTok()

proc newError(self: Parser, kind: ErrorKind, tok: Token, placeholders: varargs[string, `$`]) =
  self.errors.add errors.newError(kind, tok.file, tok.line, tok.col, tok.lexeme.len, @placeholders)
  while self.peekToken().kind notin {tkEOS, tkEOF, tkDedent}:
    discard self.nextToken()

proc expect*(self: Parser, kind: TokenKind, expected: string): ExpectedToken =
  let tok = self.nextToken()
  if tok.kind != kind:
    self.newError(errSyntax, tok, kind.mean, tok.mean, expected)
    unexpectedToken(tok)
  else:
    expectedToken(tok)

proc parseStmt(self: Parser): Stmt
proc parseExpr*(self: Parser): Expr

proc parseOr*(self: Parser): Expr
proc parseAnd*(self: Parser): Expr
proc parseCmp*(self: Parser): Expr
proc parseAddSub*(self: Parser): Expr

proc toStr(self: Parser, typ: Type): string =
  typ.toStr()

proc isType(token: Token): bool =
  token.kind in {tkInt, tkBool}

proc parseType(self: Parser): Type =
  let t = self.nextToken()

  if   t.kind == tkInt: return newIntType()
  elif t.kind == tkBool: return newBoolType()

  self.newError(errTypeSyntax, t)

proc parsePrimary(self: Parser): Expr =
  let t = self.nextToken()

  if t.kind == tkLParen:
    result = self.parseExpr()
    discard self.expect(tkRParen, "( ... ) " & self.peekToken().lexeme).ifUnexpected:
      return it.newInvalidExpr()
    return
  elif t.kind == tkNumber:
    return t.newNumber()
  elif t.kind == tkIdent:
    return t.newSymbol()
  elif t.kind == tkTrue:
    return t.newBool(true)
  elif t.kind == tkFalse:
    return t.newBool(false)
  elif t.kind == tkInvalid:
    return t.newInvalidExpr()

  self.newError(errNotExpression, t, t.mean())
  return t.newInvalidExpr()

proc parseUnary(self: Parser): Expr =
  if self.peekToken().kind in {tkPlus, tkMinus, tkNot}:
    return self.nextToken().newUnary(self.parseUnary())
  return self.parsePrimary()

proc parseMulDiv(self: Parser): Expr =
  result = self.parseUnary()

  while self.peekToken().kind in {tkStar, tkSlash}:
    result = self.nextToken().newBinary(result, self.parseUnary())

proc parseAddSub(self: Parser): Expr =
  result = self.parseMulDiv()

  while self.peekToken().kind in {tkPlus, tkMinus}:
    result = self.nextToken().newBinary(result, self.parseMulDiv())

proc parseAssignment(self: Parser): Expr =
  let left = self.parseOr()

  if self.peekToken().kind == tkEquals:
    let t = self.nextToken()
    let right = self.parseAssignment()
    return t.newBinary(left, right)

  return left

proc parseOr(self: Parser): Expr =
  result = self.parseAnd()

  while self.peekToken().kind == tkOr:
    result = self.nextToken().newBinary(result, self.parseAnd())

proc parseAnd(self: Parser): Expr =
  result = self.parseCmp()

  while self.peekToken().kind == tkAnd:
    result = self.nextToken().newBinary(result, self.parseCmp())

proc parseCmp(self: Parser): Expr =
  result = self.parseAddSub()

  while self.peekToken().kind in {tkGt, tkLt, tkGe, tkLe, tkEq, tkNe}:
    result = self.nextToken().newBinary(result, self.parseAddSub())

proc parseExpr*(self: Parser): Expr =
  self.parseAssignment()

proc parseDecl*(self: Parser, typ: Type): Stmt =
  let mut = if self.peekToken().kind == tkMut: 
    discard self.nextToken()
    true
  else:
    false

  let name = self.expect(tkIdent, self.toStr(typ) & " ident = ...").ifUnexpected:
    return it.newInvalidStmt()
  
  var value: Expr = nil
  if self.peekToken().kind == tkEquals:
    discard self.nextToken()
    value = self.parseExpr()

  return newDecl(name, typ, mut, value)

proc parseBlock(self: Parser): tuple[ok: bool, res: Stmt] =
  let colon = self.expect(tkColon, "...: " & self.peekToken().lexeme & " ...").ifUnexpected:
    return (false, it.newInvalidStmt())

  let b = colon.newBlock(@[])

  if self.peekToken().kind != tkIndent:
    b.stmts.add self.parseStmt()
    return (true, b)

  discard self.expect(tkIndent, "if ...:\\n  " & self.peekToken().lexeme & "...\\n").ifUnexpected:
    return (false, it.newInvalidStmt())

  while self.peekToken().kind != tkDedent:
    b.stmts.add self.parseStmt()
    if self.peekToken().kind == tkIndent:
      let t = self.peekToken()
      self.newError(errIndent, t)
      return (false, t.newInvalidStmt())
    if self.peekToken().kind in {tkEOF, tkDedent, tkElif, tkElse}: break
    
    discard self.expect(tkEOS, 
      "...; " & self.peekToken().lexeme & "` or `...\\n " & self.peekToken().lexeme)

    if self.peekToken().kind == tkIndent:
      let t = self.peekToken()
      self.newError(errIndent, t)
      return (false, t.newInvalidStmt())
    if self.peekToken().kind in {tkEOF, tkDedent, tkElif, tkElse}: break

  discard self.expect(tkDedent, "if ...:\\n  ...\\n" & self.peekToken().lexeme).ifUnexpected:
    return (false, it.newInvalidStmt())

  return (true, b)

template blockUnwrap(blockRes: tuple[ok: bool, res: Stmt]): untyped =
  Block((let (ok, res) = blockRes; if not ok: return res else: res))

proc parseBranch*(self: Parser, t: Token): Stmt =
  let cond = self.parseExpr()
  let ifThen = self.parseBlock().blockUnwrap()

  var elifs: typeof(Branch.elifs)
  var elseThen: Block

  while self.peekToken().kind == tkElif:
    discard self.nextToken()
    let cond = self.parseExpr()
    let elifThen = self.parseBlock().blockUnwrap()
    elifs.addElif(cond, elifThen)

  if self.peekToken().kind == tkElse:
    discard self.nextToken()
    elseThen = self.parseBlock().blockUnwrap()

  return t.newBranch(cond, ifThen, elifs, elseThen)

proc parseStmt(self: Parser): Stmt =
  let t = self.peekToken()

  if t.isType(): return self.parseDecl(self.parseType())
  elif t.kind == tkIf: return self.parseBranch(self.nextToken())

  let expr = self.parseExpr()
  return expr.token.newExprStmt(expr)

proc parse*(self: Parser): Stmt =
  let blockk: Block = Token().newBlock(@[])

  while self.peekToken().kind != tkEOF:
    blockk.stmts.add(self.parseStmt())
    if self.peekToken().kind == tkEOF: break
    # EOS опционален: после выхода из блока новый стейт идёт сразу (Dedent уже разделитель).
    if self.peekToken().kind == tkEOS:
      discard self.nextToken()

  return blockk