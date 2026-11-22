import ../[ast, types]
import ../parser/tokens
import std/[strutils]

type
  Nimgen* = ref object
    indentLevel*: Natural = 0
    blockMarker*: string = ":"
    tmpCounter: Natural = 0

proc newNimgen*(): Nimgen =
  Nimgen()

proc visit*(self: Nimgen, node: Expr): string
proc visit*(self: Nimgen, node: Stmt): string

template emit(args: varargs[string, `$`]): untyped =
  var parts: seq[string]
  for arg in args:
    parts.add $arg
  result.add parts.join("")

const nimKeywords = [
  "addr", "and", "as", "asm", "bind", "block", "break", "case", "cast",
  "concept", "const", "continue", "converter", "defer", "discard", "distinct",
  "div", "do", "elif", "else", "end", "enum", "except", "export", "finally",
  "for", "from", "func", "if", "import", "in", "include", "interface", "is",
  "isnot", "iterator", "let", "macro", "method", "mixin", "mod", "nil", "not",
  "notin", "object", "of", "or", "out", "proc", "ptr", "raise", "ref",
  "return", "shl", "shr", "static", "template", "try", "tuple", "type",
  "using", "var", "when", "while", "xor", "yield"
]

proc encChar(c: char): string =
  case c
  of '_': "zu"
  of 'z': "zz"
  else:
    if c.isDigit:        "z" & c
    elif c.isUpperAscii: "zc" & toLowerAscii(c)
    else:                $c

proc encodeIdent(sym: string): string =
  var enc = ""
  for c in sym:
    enc.add encChar(c)
  enc

proc normSym(sym: string): string =
  let enc = encodeIdent(sym)
  if enc in nimKeywords:
    result = "`" & enc & "`"
  else:
    result = enc

proc mangleFuncName(sym: string, overloadId: int): string =
  encodeIdent(sym) & "za" & $overloadId

proc pushScope(self: Nimgen) =
  self.indentLevel += 1

proc popScope(self: Nimgen) =
  self.indentLevel -= 1

proc visit*(self: Nimgen, node: Number): string =
  emit node.value

proc visit*(self: Nimgen, node: Bool): string =
  emit node.value

proc visit*(self: Nimgen, node: Symbol): string =
  emit normSym(node.token.lexeme)

proc visit*(self: Nimgen, node: Call): string =
  if node.resolvedOverloadId > 0 and node.value.kind == nkSymbol:
    emit mangleFuncName(Symbol(node.value).token.lexeme,
      node.resolvedOverloadId)
  else:
    emit self.visit(node.value)
  emit "("
  var args: seq[string]
  for arg in node.arguments:
    args.add self.visit(arg)
  emit args.join(", "), ")"

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
  case expr.kind
  of nkBinary: return self.getReturnedLValue(Binary(expr).lvalue)
  of nkCall:   return self.visit(expr)
  else:        return self.visit(expr)

proc newTmp(self: Nimgen): string =
  result = "`kovy tmp " & $self.tmpCounter & "`"
  inc self.tmpCounter

proc visit*(self: Nimgen, node: Binary): string =
  let op = nimOp(node.token)
  if op == "=":
    if node.lvalue.kind == nkCall:
      let tmp = self.newTmp()
      emit "(block:\n"
      self.pushScope()
      let pad = "  ".repeat(self.indentLevel)
      emit pad, "let ", tmp, " = addr ", self.visit(node.lvalue), "\n"
      emit pad, tmp, "[] = ", self.visit(node.rvalue), "\n"
      emit pad, tmp, "[]"
      self.popScope()
      emit ")"
    else:
      emit "(", self.parenIfBin(node.lvalue), " ", op, " ",
           self.parenIfBin(node.rvalue), "; ",
           self.getReturnedLValue(node.lvalue), ")"
  else:
    emit self.parenIfBin(node.lvalue), " ", op, " ", self.parenIfBin(node.rvalue)

proc visit*(self: Nimgen, node: Unary): string =
  emit node.token.nimOp()
  if node.value.kind in {nkUnary, nkBinary}:
    emit "(", self.visit(node.value), ")"
  else:
    emit self.visit(node.value)

template indent(self: Nimgen): string =
  "  ".repeat(self.indentLevel)

proc visit*(self: Nimgen, node: Block): string =
  self.pushScope()
  emit self.blockMarker & "\n"
  self.blockMarker = ":"
  let len = node.stmts.len
  for n, stmt in node.stmts:
    emit self.indent(), self.visit(stmt)
    let newline = if len - n > 1: "\n" else: ""
    if stmt.kind in {nkBranch, nkWhile, nkFuncDecl}:
      emit newline
    else:
      emit ";" & newline
  self.popScope()

proc visit*(self: Nimgen, node: ExprStmt): string =
  if node.expr.kind == nkBinary and (let expr = Binary(node.expr); expr).token.kind == tkEquals:
    emit self.visit(expr.lvalue) & " = " & self.visit(expr.rvalue)
  elif node.expr.kind == nkCall and Call(node.expr).isVoidCall:
    # Nim rejects `discard f()` when `f` returns void.
    emit self.visit(node.expr)
  else:
    emit "discard ", self.visit(node.expr)

proc nimType(typ: Type): string =
  return typ.toStr()

proc visit*(self: Nimgen, node: Decl): string =
  let typ = node.typ.nimType()
  for i, entry in node.declEntries:
    if i > 0:
      emit "; "
    # `let` requires an initializer in Nim, so uninitialized declarations use
    # `var`; Kovy's own sema still enforces immutability for non-mut symbols.
    emit (if node.mut or entry.value == nil: "var " else: "let "),
         normSym(entry.name), ": ", typ
    if entry.value != nil:
      emit " = ", self.visit(entry.value)

proc visit*(self: Nimgen, node: Branch): string =
  emit "if ", self.visit(node.cond), self.visit(node.ifThen)

  for (cond, elifThen) in node.elifs:
    emit "\n", self.indent(), "elif ", self.visit(cond), self.visit(elifThen)

  if node.elseThen != nil:
    emit "\n", self.indent(), "else", self.visit(node.elseThen)

proc visit*(self: Nimgen, node: While): string =
  emit "while ", self.visit(node.cond), self.visit(node.body)

proc visit*(self: Nimgen, node: Break): string =
  emit "break"

proc visit*(self: Nimgen, node: Continue): string =
  emit "continue"

proc visit*(self: Nimgen, node: FuncDecl): string =
  let name =
    if node.overloadId > 0: mangleFuncName(node.token.lexeme, node.overloadId)
    else: normSym(node.token.lexeme)
  emit "proc ", name, "("

  var args: seq[string]
  for decl in node.arguments:
    for entry in decl.declEntries:
      args.add normSym(entry.name) & (if decl.mut: ": var " else: ": ") & nimType(decl.typ)

  emit args.join(", "), ")" & (if node.mut: ": var " else: ": ") & nimType(node.returnType)

  if node.body != nil:
    self.blockMarker = " = "
    emit self.visit(node.body)

proc visit*(self: Nimgen, node: Return): string =
  emit "return"
  if node.value != nil:
    emit " ", self.visit(node.value)

proc visit*(self: Nimgen, node: Expr): string =
  case node.kind
  of nkNumber: self.visit(Number(node))
  of nkBool:   self.visit(Bool(node))
  of nkSymbol: self.visit(Symbol(node))
  of nkBinary: self.visit(Binary(node))
  of nkUnary:  self.visit(Unary(node))
  of nkCall:   self.visit(Call(node))
  else: ""

proc visit*(self: Nimgen, node: Stmt): string =
  case node.kind
  of nkBlock:    self.visit(Block(node))
  of nkExprStmt: self.visit(ExprStmt(node))
  of nkDecl:     self.visit(Decl(node))
  of nkBranch:   self.visit(Branch(node))
  of nkWhile:    self.visit(While(node))
  of nkBreak:    self.visit(Break(node))
  of nkContinue: self.visit(Continue(node))
  of nkFuncDecl: self.visit(FuncDecl(node))
  of nkReturn:   self.visit(Return(node))
  else: ""

proc emit*(ng: Nimgen, node: Node): string =
  emit "block", ng.visit(Block(node))