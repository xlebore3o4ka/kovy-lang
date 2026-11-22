import parser/tokens
import std/[strutils]
import std/[sequtils]
import std/[tables]
import std/[algorithm]
import types

type
  NodeKind* = enum
    nkInvalid
    nkNumber
    nkBool
    nkBinary
    nkUnary
    nkBlock
    nkSymbol
    nkExprStmt
    nkDecl
    nkBranch
    nkWhile
    nkBreak
    nkContinue
    nkFuncDecl
    nkReturn
    nkCall

  Node* = ref object of RootObj
    kind*: NodeKind
    token*: Token
    
  Expr* = ref object of Node
  Stmt* = ref object of Node

  InvalidExpr* = ref object of Expr
  InvalidStmt* = ref object of Stmt

  Number* = ref object of Expr
    value*: int
  Bool* = ref object of Expr
    value*: bool
  Binary* = ref object of Expr
    lvalue*: Expr
    rvalue*: Expr
  Unary* = ref object of Expr
    value*: Expr
  Block* = ref object of Stmt
    stmts*: seq[Stmt]
  Symbol* = ref object of Expr
    resolvedOverloadId*: int  # 0 = not a reference to a global function
  ExprStmt* = ref object of Stmt
    expr*: Expr
  Decl* = ref object of Stmt
    typ*: Type
    mut*: bool
    decls*: Table[string, tuple[token: Token, value: Expr]]
  Branch* = ref object of Stmt
    cond*: Expr
    ifThen*: Block
    elifs*: seq[tuple[cond: Expr, elifThen: Block]]
    elseThen*: Block
  While* = ref object of Stmt
    cond*: Expr
    body*: Block
  Break* = ref object of Stmt
  Continue* = ref object of Stmt
  FuncDecl* = ref object of Stmt
    returnType*: Type
    mut*: bool
    arguments*: seq[Decl]
    body*: Block
    overloadId*: int  # 0 = not assigned yet
  Return* = ref object of Stmt
    value*: Expr
  Call* = ref object of Expr
    value*: Expr
    arguments*: seq[Expr]
    resolvedOverloadId*: int  # 0 = resolved without an overload set
    isVoidCall*: bool         # sema result: the callee returns void

proc newInvalidStmt*(token: Token): Stmt =
  InvalidStmt(kind: nkInvalid, token: token)

proc newInvalidExpr*(token: Token): Expr =
  InvalidExpr(kind: nkInvalid, token: token)

proc newNumber*(token: Token): Number =
  Number(kind: nkNumber, token: token, value: parseInt(token.lexeme))

proc newBool*(token: Token, value: bool): Bool =
  Bool(kind: nkBool, token: token, value: value)

proc newBinary*(token: Token, lvalue, rvalue: Expr): Binary =
  Binary(kind: nkBinary, token: token, lvalue: lvalue, rvalue: rvalue)

proc newUnary*(token: Token, value: Expr): Unary =
  Unary(kind: nkUnary, token: token, value: value)

proc newBlock*(token: Token, stmts: seq[Stmt]): Block =
  Block(kind: nkBlock, token: token, stmts: stmts)

proc newSymbol*(token: Token): Symbol =
  Symbol(kind: nkSymbol, token: token)

proc newExprStmt*(token: Token, expr: Expr): ExprStmt =
  ExprStmt(kind: nkExprStmt, token: token, expr: expr)

proc newDecl*(token: Token, typ: Type, mut: bool,
              decls: Table[string, tuple[token: Token, value: Expr]]): Decl =
  Decl(kind: nkDecl, token: token, typ: typ, mut: mut, decls: decls)

proc newDecl*(token: Token, typ: Type, mut: bool): Decl =
  newDecl(token, typ, mut,
    initTable[string, tuple[token: Token, value: Expr]]())

proc addDecl*(decl: Decl, name: Token, value: Expr) =
  decl.decls[name.lexeme] = (token: name, value: value)

proc addDecl*(decl: Decl, name: Token) =
  decl.decls[name.lexeme] = (token: name, value: nil)

proc getDeclValue*(decl: Decl, name: string): Expr =
  if name in decl.decls:
    result = decl.decls[name].value

proc getDeclToken*(decl: Decl, name: string): Token =
  if name in decl.decls:
    result = decl.decls[name].token

proc declEntries*(decl: Decl): seq[tuple[name: string, token: Token, value: Expr]] =
  # Tables do not preserve insertion order, so recover the source order.
  for name, entry in decl.decls:
    result.add((name: name, token: entry.token, value: entry.value))
  result.sort(proc(a, b: tuple[name: string, token: Token, value: Expr]): int =
    result = cmp(a.token.line, b.token.line)
    if result == 0:
      result = cmp(a.token.col, b.token.col)
    if result == 0:
      result = cmp(a.name, b.name)
  )

proc newBranch*(token: Token, cond: Expr, ifThen: Block,
                elifs: seq[tuple[cond: Expr, elifThen: Block]],
                elseThen: Block): Branch =
  Branch(kind: nkBranch, token: token, cond: cond, ifThen: ifThen,
         elifs: elifs, elseThen: elseThen)

proc newWhile*(token: Token, cond: Expr, body: Block): While =
  While(kind: nkWhile, token: token, cond: cond, body: body)

proc newBreak*(token: Token): Break =
  Break(kind: nkBreak, token: token)

proc newContinue*(token: Token): Continue =
  Continue(kind: nkContinue, token: token)

proc newFuncDecl*(token: Token, returnType: Type, mut: bool, arguments: seq[Decl],
                 body: Block): FuncDecl =
  FuncDecl(kind: nkFuncDecl, token: token, returnType: returnType, mut: mut,
           arguments: arguments, body: body)

proc newReturn*(token: Token, value: Expr): Return =
  Return(kind: nkReturn, token: token, value: value)

proc newCall*(token: Token, value: Expr, arguments: seq[Expr]): Call =
  Call(kind: nkCall, token: token, value: value, arguments: arguments)

proc addElif*(s: var seq[tuple[cond: Expr, elifThen: Block]],
              cond: Expr, elifThen: Block) =
  s.add((cond: cond, elifThen: elifThen))

proc toStr*(expr: Expr): string

proc binaryToStr(l, r: Expr, token: Token): string =
  let ls = if l.kind == nkBinary: "(" & l.toStr & ")" else: l.toStr
  let rs = if r.kind == nkBinary: "(" & r.toStr & ")" else: r.toStr
  ls & " " & token.lexeme & " " & rs

proc toStr*(expr: Expr): string =
  case expr.kind
  of nkNumber: $(Number(expr).value)
  of nkBool:   $Bool(expr).value
  of nkBinary: binaryToStr(Binary(expr).lvalue, Binary(expr).rvalue, expr.token)
  of nkUnary:
    let un = Unary(expr)
    if un.token.kind == tkNot:
      un.token.lexeme & " " & un.value.toStr
    else:
      un.token.lexeme & un.value.toStr
  of nkSymbol: expr.token.lexeme
  of nkCall:
    let c = Call(expr)
    c.value.toStr & "(" & c.arguments.mapIt(it.toStr).join(", ") & ")"
  else: ""

proc toStr*(stmt: Stmt): string =
  case stmt.kind
  of nkBlock:
    let b = Block(stmt)
    "{" & b.stmts.mapIt(it.toStr).join("; ") & "}"
  of nkExprStmt: ExprStmt(stmt).expr.toStr
  of nkDecl:
    let d = Decl(stmt)
    var parts: seq[string]
    for entry in d.declEntries:
      parts.add entry.name &
        (if entry.value != nil: " = " & entry.value.toStr else: "")
    d.typ.toStr & " " & parts.join(", ")
  of nkBranch:
    let b = Branch(stmt)
    var parts = @["if " & b.cond.toStr & " " & b.ifThen.toStr]
    for (c, t) in b.elifs:
      parts.add "elif " & c.toStr & " " & t.toStr
    if b.elseThen != nil:
      parts.add "else " & b.elseThen.toStr
    parts.join(" ")
  of nkWhile:
    let w = While(stmt)
    "while " & w.cond.toStr & " " & w.body.toStr
  of nkBreak: "break"
  of nkContinue: "continue"
  of nkFuncDecl:
    let f = FuncDecl(stmt)
    f.returnType.toStr & " " & f.token.lexeme &
      "(" & f.arguments.mapIt(it.toStr).join(", ") & ")" &
      (if f.body != nil: " " & f.body.toStr else: "")
  of nkReturn:
    let r = Return(stmt)
    "return" & (if r.value != nil: " " & r.value.toStr else: "")
  of nkInvalid: ""
  else: ""