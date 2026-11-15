import ../[ast, types]
import ../parser/tokens
import std/strutils

type
  Nimgen* = ref object

proc newNimgen*(): Nimgen =
  Nimgen()

proc visit*(self: Nimgen, node: Expr): string
proc visit*(self: Nimgen, node: Stmt): string

template emit(args: varargs[string, `$`]): untyped =
  var parts: seq[string]
  for arg in args:
    parts.add $arg
  return parts.join("")

proc normSym(sym: string): string =
  result = "s_" & sym & "_s"

proc visit*(self: Nimgen, node: Number): string =
  emit node.value

proc visit*(self: Nimgen, node: Bool): string =
  emit node.value

proc visit*(self: Nimgen, node: Symbol): string =
  emit normSym(node.token.lexeme)

template parenIfBin(it, n: untyped): string =
  var res: string
  if n.kind == nkBinary: res.add "("
  res.add it.visit(n)
  if n.kind == nkBinary: res.add ")"
  res

proc nimOp(k: Token): string =
  case k.kind:
  of tkSlash: "div"
  of tkNot:   "not "
  else: k.lexeme

proc getReturnedLValue(self: Nimgen, expr: Expr): string =
  if expr.kind == nkBinary: return self.getReturnedLValue(Binary(expr).lvalue)
  return self.visit(expr)

proc visit*(self: Nimgen, node: Binary): string =
  let op = nimOp(node.token)
  var res: string
  if op == "=":
    res.add "("

  res.add self.parenIfBin(node.lvalue)
  res.add " " & op & " "
  res.add self.parenIfBin(node.rvalue)

  if op == "=":
    res.add "; "
    res.add self.getReturnedLValue(node.lvalue)
    res.add ")"
  res

proc visit*(self: Nimgen, node: Unary): string =
  emit node.token.nimOp(), self.parenIfBin(node.value)

proc visit*(self: Nimgen, node: Block): string =
  var res: string
  for stmt in node.stmts:
    res.add self.visit(stmt)
    res.add ";\n"
  res

proc visit*(self: Nimgen, node: ExprStmt): string =
  emit "discard ", self.visit(node.expr)

proc nimType(typ: Type): string =
  return typ.toStr()

proc visit*(self: Nimgen, node: Decl): string =
  var res: string
  res.add (if node.mut: "var " else: "let ")
  res.add normSym(node.token.lexeme)
  res.add ": " & node.typ.nimType()
  if node.value != nil:
    res.add " = "
    res.add self.visit(node.value)
  res

proc visit*(self: Nimgen, node: Expr): string =
  case node.kind
  of nkNumber: self.visit(Number(node))
  of nkBool:   self.visit(Bool(node))
  of nkSymbol: self.visit(Symbol(node))
  of nkBinary: self.visit(Binary(node))
  of nkUnary:  self.visit(Unary(node))
  else: ""

proc visit*(self: Nimgen, node: Stmt): string =
  case node.kind
  of nkBlock:    self.visit(Block(node))
  of nkExprStmt: self.visit(ExprStmt(node))
  of nkDecl:     self.visit(Decl(node))
  else: ""

proc emit*(ng: Nimgen, node: Node): string =
  ng.visit(Block(node))