import lexer, tokens
import ../[errors, ast, types]
import std/[macros, tables]

type
  Parser* = ref object
    lexer*: Lexer
    errors*: ErrorContext
    highLevelExpr: bool

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
proc parseExpr*(self: Parser, prevToken: Token): Expr

proc toStr(self: Parser, typ: Type): string =
  typ.toStr()

proc isType(token: Token): bool =
  token.kind in {tkInt, tkBool, tkVoid}

proc parseType(self: Parser): Type =
  let t = self.nextToken()

  if   t.kind == tkInt: result = newIntType()
  elif t.kind == tkBool: result = newBoolType()
  elif t.kind == tkVoid: result = newVoidType()
  else:
    self.newError(errTypeSyntax, t)
    return newErrorType()

  while (let tok = self.peekToken(); tok).kind in {tkLParen, tkStar}:
    if tok.kind == tkLParen:
      discard self.nextToken()

      var argTypes: seq[Type]
      while self.peekToken().kind notin {tkEOF, tkRParen}:
        let argMut = self.peekToken().kind == tkMut
        if argMut:
          discard self.nextToken()

        let argType = self.parseType()
        if argType.kind == typeError:
          return newErrorType()

        argTypes.add(if argMut: newMutableType(argType) else: argType)

        if self.peekToken().kind in {tkEOF, tkRParen}:
          break

        discard self.expect(tkComma,
          "type, " & self.peekToken().lexeme & "...").ifUnexpected:
          return newErrorType()

      discard self.expect(tkRParen, "( ... )").ifUnexpected:
        return newErrorType()

      result = newFuncType(result, argTypes)

    elif tok.kind == tkStar:
      discard self.nextToken()
      result = newPtrType(result)

proc parsePrimary(self: Parser, prevToken: Token): Expr =
  let t = self.nextToken()

  # The first primary of an expression statement is the statement root: report
  # errStatementExpected for it. Any nested primary is an ordinary expression, so the
  # flag is consumed here (one-shot) to avoid leaking into subexpressions like `x = if`.
  let stmtContext = self.highLevelExpr
  self.highLevelExpr = false

  if t.kind == tkLParen:
    result = self.parseExpr(t)
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
  elif t.kind == tkAlloc:
    if self.peekToken().isType():
      let typ = self.parseType()
      return t.newAlloc(Token(kind: tkNumber, lexeme: "1", line: t.line, col: t.col, file: t.file)
        .newNumber(), typ)
    else:
      let expr = self.parseExpr(t)
      discard self.expect(tkOf, "alloc " & expr.toStr() & " of T").ifUnexpected:
        return it.newInvalidExpr()
      let typ = self.parseType()

      return t.newAlloc(expr, typ)
  elif t.kind == tkInvalid:
    return t.newInvalidExpr()

  if stmtContext: self.newError(errStatementExpected, t, t.mean())
  else: self.newError(errExpressionExpected, t, t.mean(), prevToken.lexeme)
  return t.newInvalidExpr()

proc parsePostfix(self: Parser, prevToken: Token): Expr =
  result = self.parsePrimary(prevToken)

  while self.peekToken().kind == tkLParen:
    let t = self.nextToken()
    var arguments: seq[Expr] = @[]

    while self.peekToken().kind notin {tkEOF, tkRParen}:
      arguments.add self.parseExpr(t)
      if self.peekToken().kind in {tkEOF, tkRParen}:
        break
      discard self.expect(tkComma, arguments[^1].toStr() & ", " & self.peekToken().lexeme & "...").ifUnexpected:
        return it.newInvalidExpr()

    discard self.expect(tkRParen, "( ... ) " & self.peekToken().lexeme).ifUnexpected:
      return it.newInvalidExpr()

    result = t.newCall(result, arguments)

proc parseUnary(self: Parser, prevToken: Token): Expr =
  if self.peekToken().kind in {tkPlus, tkMinus, tkNot, tkHash, tkAddr}:
    let t = self.nextToken()
    result = t.newUnary(self.parseUnary(t))
  else:
    result = self.parsePostfix(prevToken)

proc parseMulDiv(self: Parser, prevToken: Token): Expr =
  result = self.parseUnary(prevToken)

  while self.peekToken().kind in {tkStar, tkSlash}:
    let t = self.nextToken()
    result = t.newBinary(result, self.parseUnary(t))

proc parseAddSub(self: Parser, prevToken: Token): Expr =
  result = self.parseMulDiv(prevToken)

  while self.peekToken().kind in {tkPlus, tkMinus}:
    let t = self.nextToken()
    result = t.newBinary(result, self.parseMulDiv(t))

proc parseCmp(self: Parser, prevToken: Token): Expr =
  result = self.parseAddSub(prevToken)

  while self.peekToken().kind in {tkGt, tkLt, tkGe, tkLe, tkEq, tkNe}:
    let t = self.nextToken()
    result = t.newBinary(result, self.parseAddSub(t))

proc parseAnd(self: Parser, prevToken: Token): Expr =
  result = self.parseCmp(prevToken)

  while self.peekToken().kind == tkAnd:
    let t = self.nextToken()
    result = t.newBinary(result, self.parseCmp(t))

proc parseOr(self: Parser, prevToken: Token): Expr =
  result = self.parseAnd(prevToken)

  while self.peekToken().kind == tkOr:
    let t = self.nextToken()
    result = t.newBinary(result, self.parseAnd(t))

proc parseAssignment(self: Parser, prevToken: Token): Expr =
  let left = self.parseOr(prevToken)

  if self.peekToken().kind == tkEquals:
    let t = self.nextToken()
    let right = self.parseAssignment(t)
    return t.newBinary(left, right)

  return left

proc parseExpr*(self: Parser, prevToken: Token): Expr =
  self.parseAssignment(prevToken)

template exprUnwrap(exprRes: Expr): untyped =
  let value = exprRes
  if value.kind == nkInvalid:
    return value.token.newInvalidStmt()
  value

proc parseStmts(self: Parser, b: Block) =
  while self.peekToken().kind notin {tkEOF, tkDedent}:
    b.stmts.add self.parseStmt()
    # An indented compound statement (branch/while/func) ends with a block whose dedent
    # already serves as the separator; an inline one ends with the following EOS.
    if b.stmts[^1].kind in {nkBranch, nkWhile, nkFuncDecl} and self.peekToken().kind != tkEOS:
      continue
    case self.peekToken().kind
    of tkEOS:
      discard self.nextToken()
    of tkEOF, tkDedent:
      discard
    of tkIndent:
      # A statement followed by an unexpected deeper indentation is an indentation error.
      let t = self.peekToken()
      self.newError(errIndent, t)
      break
    else:
      let t = self.peekToken()
      self.newError(errSyntax, t, tkEOS.mean, t.mean,
        "...; " & self.peekToken().lexeme & "` or `...\\n " & self.peekToken().lexeme)
      break

proc parseBlock(self: Parser,
                requireBody: bool = false): tuple[ok: bool, res: Stmt] =
  let colon = self.expect(tkColon, "...: " & self.peekToken().lexeme & " ...").ifUnexpected:
    return (false, it.newInvalidStmt())

  if requireBody and self.peekToken().kind in {tkEOS, tkEOF, tkDedent}:
    self.newError(errEmptyFunctionBody, colon)
    return (false, colon.newInvalidStmt())

  let b = colon.newBlock(@[])

  if self.peekToken().kind != tkIndent:
    b.stmts.add self.parseStmt()
    # Inline block ends with an EOS. An inline statement followed by an indented
    # block is contradictory indentation, so report errIndent; otherwise verify the
    # EOS is present. Do not consume it: consuming is the parent's (parseStmts)
    # responsibility.
    let t = self.peekToken()
    if t.kind == tkIndent:
      self.newError(errIndent, t)
    elif t.kind notin {tkEOS, tkEOF, tkDedent}:
      self.newError(errSyntax, t, tkEOS.mean, t.mean,
        "...; " & t.lexeme & "` or `...\\n " & t.lexeme)
    return (true, b)

  discard self.expect(tkIndent, "...:\\n  " & self.peekToken().lexeme & "...\\n").ifUnexpected:
    return (false, it.newInvalidStmt())

  self.parseStmts(b)

  discard self.expect(tkDedent, "...:\\n  ...\\n" & self.peekToken().lexeme).ifUnexpected:
      return (false, it.newInvalidStmt())

  if requireBody and b.stmts.len == 0:
    self.newError(errEmptyFunctionBody, colon)
    return (false, colon.newInvalidStmt())

  return (true, b)

template blockUnwrap(blockRes: tuple[ok: bool, res: Stmt]): untyped =
  Block((let (ok, res) = blockRes; if not ok: return res else: res))

proc parseDecl*(self: Parser, typ: Type): Stmt

proc parseFuncDecl*(self: Parser, typ: Type, mut: bool, name: Token): Stmt =
  discard self.nextToken()

  var arguments: seq[Decl]

  while self.peekToken().kind notin {tkEOF, tkRParen}:
    let paramType = self.parseType()
    let paramMut =
      if self.peekToken().kind == tkMut:
        discard self.nextToken()
        true
      else:
        false

    let firstName = self.expect(tkIdent,
      self.toStr(paramType) & " ident = ...").ifUnexpected:
      return it.newInvalidStmt()

    # Parameters can share a type: `int a, b` declares two int parameters.
    # A comma followed by an identifier continues the current group, while a
    # comma followed by a type starts the next one.
    var paramName = firstName
    var atNextGroup = false

    while true:
      var value: Expr = nil
      if self.peekToken().kind == tkEquals:
        value = self.parseExpr(self.nextToken()).exprUnwrap()

      # Store one name per Decl so later stages can treat every parameter
      # independently while keeping its own token and default value.
      arguments.add(paramName.newDecl(paramType, paramMut,
        {paramName.lexeme: (paramName, value)}.toTable))

      if self.peekToken().kind != tkComma:
        break

      discard self.nextToken()
      if self.peekToken().kind != tkIdent:
        atNextGroup = true
        break

      paramName = self.nextToken()

    if self.peekToken().kind in {tkEOF, tkRParen}:
      break

    if not atNextGroup:
      self.newError(errSyntax, self.peekToken())
      return self.peekToken().newInvalidStmt()

  discard self.expect(tkRParen, "( ... )").ifUnexpected:
    return it.newInvalidStmt()

  let body: Block =
    if self.peekToken().kind == tkColon:
      self.parseBlock(requireBody = true).blockUnwrap()
    else:
      nil

  return name.newFuncDecl(typ, mut, arguments, body)

proc parseDecl*(self: Parser, typ: Type): Stmt =
  let mut = if self.peekToken().kind == tkMut: 
    discard self.nextToken()
    true
  else:
    false

  let firstName = self.expect(tkIdent, self.toStr(typ) & " ident = ...").ifUnexpected:
    return it.newInvalidStmt()

  if self.peekToken().kind == tkLParen:
    return self.parseFuncDecl(typ, mut, firstName)

  let decl = newDecl(firstName, typ, mut)
  var name = firstName

  while true:
    if name.lexeme in decl.decls:
      let first = decl.decls[name.lexeme].token
      self.newError(errRedeclaration, name, name.lexeme, first.file, first.line)
      return name.newInvalidStmt()

    var value: Expr = nil
    if self.peekToken().kind == tkEquals:
      value = self.parseExpr(self.nextToken()).exprUnwrap()

    if value == nil:
      decl.addDecl(name)
    else:
      decl.addDecl(name, value)

    if self.peekToken().kind != tkComma:
      break

    discard self.nextToken()
    name = self.expect(tkIdent, self.toStr(typ) & " ident = ...").ifUnexpected:
      return it.newInvalidStmt()

  return decl

proc parseBranch*(self: Parser, t: Token): Stmt =
  let cond = self.parseExpr(t).exprUnwrap()

  var elifs: typeof(Branch.elifs)
  var elseThen: Block

  let ifThen = self.parseBlock().blockUnwrap()

  while self.peekToken().kind == tkElif:
    let cond = self.parseExpr(self.nextToken()).exprUnwrap()
    let elifThen = self.parseBlock().blockUnwrap()
    elifs.addElif(cond, elifThen)

  if self.peekToken().kind == tkElse:
    discard self.nextToken()
    elseThen = self.parseBlock().blockUnwrap()

  return t.newBranch(cond, ifThen, elifs, elseThen)

proc parseWhile*(self: Parser, t: Token): Stmt =
  let cond = self.parseExpr(t).exprUnwrap()
  let body = self.parseBlock().blockUnwrap()
  return t.newWhile(cond, body)

proc parseBreak(self: Parser, t: Token): Stmt =
  t.newBreak()

proc parseContinue(self: Parser, t: Token): Stmt =
  t.newContinue()

proc parseReturn(self: Parser, t: Token): Stmt =
  if self.peekToken().kind == tkEOS:
    return t.newReturn(nil)
  let value = self.parseExpr(t).exprUnwrap()
  return t.newReturn(value)

proc parseStmt(self: Parser): Stmt =
  let t = self.peekToken()

  if t.isType(): return self.parseDecl(self.parseType())
  elif t.kind == tkIf: return self.parseBranch(self.nextToken())
  elif t.kind == tkWhile: return self.parseWhile(self.nextToken())
  elif t.kind == tkBreak: return self.parseBreak(self.nextToken())
  elif t.kind == tkContinue: return self.parseContinue(self.nextToken())
  elif t.kind == tkReturn: return self.parseReturn(self.nextToken())

  self.highLevelExpr = true
  let expr = self.parseExpr(t)
  self.highLevelExpr = false
  return expr.token.newExprStmt(expr)

proc parse*(self: Parser): Stmt =
  let blockk: Block = Token().newBlock(@[])
  self.parseStmts(blockk)
  return blockk
