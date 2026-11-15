import parser/tokens
import std/[strutils]
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
  ExprStmt* = ref object of Stmt
    expr*: Expr
  Decl* = ref object of Stmt
    typ*: Type
    mut*: bool
    value*: Expr
  Branch* = ref object of Stmt
    cond*: Expr
    ifThen*: Block
    elifs*: seq[tuple[cond: Expr, elifThen: Block]]
    elseThen*: Block

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

proc newDecl*(token: Token, typ: Type, mut: bool, value: Expr): Decl =
  Decl(kind: nkDecl, token: token, typ: typ, mut: mut, value: value)

proc newBranch*(token: Token, cond: Expr, ifThen: Block,
                elifs: seq[tuple[cond: Expr, elifThen: Block]],
                elseThen: Block): Branch =
  Branch(kind: nkBranch, token: token, cond: cond, ifThen: ifThen,
         elifs: elifs, elseThen: elseThen)

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
  else: ""