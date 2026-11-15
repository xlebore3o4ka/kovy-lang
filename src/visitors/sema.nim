import ../[ast, types, errors]
import ../parser/tokens
import std/[tables]

type
  Sym = object
    token: Token
    symbolType: Type

  Scope = ref object
    depth: Natural
    symbolTable: Table[string, Sym]
    case isGlobal: bool
    of false: parent: Scope
    of true: discard

  Sema* = ref object
    errors*: ErrorContext

    currentScope: Scope
    symbolScopeStack: Table[string, seq[Scope]]

proc newSema*(errors: ErrorContext): Sema =
  Sema(errors: errors,
       currentScope: Scope(isGlobal: true, symbolTable: initTable[string, Sym](), depth: 0))

proc visit*(self: Sema, node: Expr): Type
proc visit*(self: Sema, node: Stmt): bool

proc newSymbol(self: Sema, token: Token, typ: Type) =
  self.currentScope.symbolTable[token.lexeme] = Sym(token: token, symbolType: typ)
  self.symbolScopeStack.mgetOrPut(token.lexeme, @[]).add(self.currentScope)

proc pushScope(self: Sema) =
  let depth = self.currentScope.depth
  self.currentScope = Scope(isGlobal: false, symbolTable: initTable[string, Sym](), 
    parent: self.currentScope, depth: depth + 1)

proc popScope(self: Sema) =
  let scope = self.currentScope
  for name in scope.symbolTable.keys:
    discard self.symbolScopeStack[name].pop()
  self.currentScope = scope.parent

proc symbolExists(self: Sema, name: string): bool =
  name in self.symbolScopeStack and self.symbolScopeStack[name].len > 0

proc getSymbol(self: Sema, name: string): Sym =
  if not self.symbolExists(name):
    return Sym()
  let scope = self.symbolScopeStack[name][^1]
  result = scope.symbolTable[name]

proc suggestName(self: Sema, name: string): string =
  return "<not-implemented-yet>"

proc symbolExistsInScope(self: Sema, name: string): bool =
  let exists = name in self.currentScope.symbolTable
  return exists

const fitSets: Table[TypeKind, set[TypeKind]] = {
  typeNumberLit: {typeNumberLit, typeInt},
  typeInt: {typeInt},
  typeBoolLit: {typeBoolLit, typeBool},
  typeBool: {typeBool},
}.toTable

proc fits(self: Sema, typ: Type, expectedType: Type): bool =
  if typ.kind == typeError or expectedType.kind == typeError:
    return true
  if typ.kind == typeMutable:
    return self.fits(typ.args[0], expectedType)
  expectedType.kind in fitSets.getOrDefault(typ.kind, {})

const unOpResult: Table[TokenKind, Table[TypeKind, TypeKind]] = {
  tkPlus:  {typeNumberLit: typeInt, typeInt: typeInt}.toTable,
  tkMinus: {typeNumberLit: typeInt, typeInt: typeInt}.toTable,
  tkNot:   {typeBoolLit: typeBool, typeBool: typeBool}.toTable,
}.toTable

const binOpResult: Table[TokenKind, Table[(TypeKind, TypeKind), TypeKind]] = {
  tkPlus:  {(typeNumberLit, typeNumberLit): typeInt,
            (typeInt, typeNumberLit): typeInt,
            (typeNumberLit, typeInt): typeInt,
            (typeInt, typeInt): typeInt}.toTable,
  tkMinus: {(typeNumberLit, typeNumberLit): typeInt,
            (typeInt, typeNumberLit): typeInt,
            (typeNumberLit, typeInt): typeInt,
            (typeInt, typeInt): typeInt}.toTable,
  tkStar:  {(typeNumberLit, typeNumberLit): typeInt,
            (typeInt, typeNumberLit): typeInt,
            (typeNumberLit, typeInt): typeInt,
            (typeInt, typeInt): typeInt}.toTable,
  tkSlash: {(typeNumberLit, typeNumberLit): typeInt,
            (typeInt, typeNumberLit): typeInt,
            (typeNumberLit, typeInt): typeInt,
            (typeInt, typeInt): typeInt}.toTable,
  tkGt:  {(typeNumberLit, typeNumberLit): typeBool,
           (typeInt, typeNumberLit): typeBool,
           (typeNumberLit, typeInt): typeBool,
           (typeInt, typeInt): typeBool}.toTable,
  tkLt:  {(typeNumberLit, typeNumberLit): typeBool,
           (typeInt, typeNumberLit): typeBool,
           (typeNumberLit, typeInt): typeBool,
           (typeInt, typeInt): typeBool}.toTable,
  tkGe:  {(typeNumberLit, typeNumberLit): typeBool,
           (typeInt, typeNumberLit): typeBool,
           (typeNumberLit, typeInt): typeBool,
           (typeInt, typeInt): typeBool}.toTable,
  tkLe:  {(typeNumberLit, typeNumberLit): typeBool,
           (typeInt, typeNumberLit): typeBool,
           (typeNumberLit, typeInt): typeBool,
           (typeInt, typeInt): typeBool}.toTable,
  tkEq:  {(typeNumberLit, typeNumberLit): typeBool,
           (typeInt, typeNumberLit): typeBool,
           (typeNumberLit, typeInt): typeBool,
           (typeInt, typeInt): typeBool,
           (typeBoolLit, typeBoolLit): typeBool,
           (typeBool, typeBool): typeBool,
           (typeBoolLit, typeBool): typeBool,
           (typeBool, typeBoolLit): typeBool}.toTable,
  tkNe:  {(typeNumberLit, typeNumberLit): typeBool,
           (typeInt, typeNumberLit): typeBool,
           (typeNumberLit, typeInt): typeBool,
           (typeInt, typeInt): typeBool,
           (typeBoolLit, typeBoolLit): typeBool,
           (typeBool, typeBool): typeBool,
           (typeBoolLit, typeBool): typeBool,
           (typeBool, typeBoolLit): typeBool}.toTable,
  tkAnd: {(typeBoolLit, typeBoolLit): typeBool,
          (typeBool, typeBool): typeBool,
          (typeBoolLit, typeBool): typeBool,
          (typeBool, typeBoolLit): typeBool}.toTable,
  tkOr:  {(typeBoolLit, typeBoolLit): typeBool,
          (typeBool, typeBool): typeBool,
          (typeBoolLit, typeBool): typeBool,
          (typeBool, typeBoolLit): typeBool}.toTable,
}.toTable

proc binResult(token: TokenKind, ltype, rtype: Type): TypeKind =
  var ltyp: Type = ltype
  var rtyp: Type = rtype
  if ltype.kind == typeMutable:
    ltyp = ltype.args[0]
  if rtype.kind == typeMutable:
    rtyp = rtype.args[0]
  binOpResult.getOrDefault(token, initTable[(TypeKind, TypeKind), TypeKind]()).getOrDefault(
    (ltyp.kind, rtyp.kind), typeError)

proc unResult(token: TokenKind, typ: Type): TypeKind =
  var ltyp: Type = typ
  if typ.kind == typeMutable:
    ltyp = typ.args[0]
  unOpResult.getOrDefault(token, initTable[TypeKind, TypeKind]()).getOrDefault(
    ltyp.kind, typeError)

proc typeOfKind(kind: TypeKind): Type =
  case kind
  of typeInt: newIntType()
  of typeBool: newBoolType()
  else: newErrorType()

template handleErrorType(self: Sema, types: varargs[Type]): untyped =
  for typ in types:
    if typ.kind == typeError:
      return typ

template manageErrorType(self: Sema, types: varargs[Type]): untyped =
  for typ in types:
    if typ.kind == typeError:
      return false

proc newError(self: Sema, node: Node, kind: ErrorKind, placeholders: varargs[string, `$`]) =
  let t = node.token
  self.errors.add errors.newError(kind, t.file, t.line, t.col, t.lexeme.len, @placeholders)

proc visit*(self: Sema, node: Number): Type =
  return newNumberLitType()

proc visit*(self: Sema, node: Bool): Type =
  return newBoolLitType()

proc visit*(self: Sema, node: Symbol): Type =
  let name = node.token.lexeme
  if not self.symbolExists(name):
    self.newError(node, errUnknownSymbol, name, self.suggestName(name))

  return self.getSymbol(name).symbolType

proc visit*(self: Sema, node: Binary): Type =
  let ltype = self.visit(node.lvalue)
  let rtype = self.visit(node.rvalue)
  self.handleErrorType(ltype, rtype)

  if node.token.kind == tkEquals:
    if ltype.kind != typeMutable:
      self.newError(node, errImmutableAssignment, node.lvalue.toStr())
      return newErrorType()
    let inner = ltype.args[0]
    if not self.fits(rtype, inner):
      self.newError(node, errBinaryMismatch, node.token.mean(), rtype.toStr & " " & node.token.lexeme & " " & inner.toStr)
      return newErrorType()
    return newMutableType(inner)

  let res = binResult(node.token.kind, ltype, rtype)
  if res == typeError:
    self.newError(node, errBinaryMismatch, node.token.mean(), ltype.toStr & " " & node.token.lexeme & " " & rtype.toStr)
    return newErrorType()
  return typeOfKind(res)

proc visit*(self: Sema, node: Unary): Type =
  let typ = self.visit(node.value)
  self.handleErrorType(typ)

  let res = unResult(node.token.kind, typ)
  if res == typeError:
    self.newError(node, errUnaryMismatch, node.token.mean(), typ.toStr)
    return newErrorType()
  return typeOfKind(res)

proc visit*(self: Sema, node: Block): bool =
  for stmt in node.stmts:
    discard self.visit(stmt)
  return true

proc visit*(self: Sema, node: ExprStmt): bool =
  self.manageErrorType(self.visit(node.expr))
  return true

proc visit*(self: Sema, node: Decl): bool =
  let expectedType = node.typ
  let name = node.token.lexeme

  var successfulness = true

  if node.value != nil:
    let typ = self.visit(node.value)
    self.manageErrorType(typ)
    if not self.fits(typ, expectedType):
      self.newError(node, errDoesNotFit, typ.toStr, expectedType.toStr)
      successfulness = false

  if self.symbolExistsInScope(name):
    let sym = self.getSymbol(name)
    let file = sym.token.file
    let line = sym.token.line
    self.newError(node, errRedeclaration, name, file, line)
    successfulness = false

  let typ = if node.mut: newMutableType(expectedType) else: expectedType
  self.newSymbol(node.token, typ)

  return successfulness

proc visit*(self: Sema, node: Branch): bool =
  let condType = self.visit(node.cond)
  let boolType = newBoolType()

  var successfulness = true

  if not self.fits(condType, boolType):
    self.newError(node, errDoesNotFit, condType.toStr, boolType.toStr)
    successfulness = false

  self.pushScope()
  if not self.visit(node.ifThen):
    successfulness = false
  self.popScope()

  for (cond, elifThen) in node.elifs:
    let condType = self.visit(node.cond)

    if not self.fits(condType, boolType):
      self.newError(node, errDoesNotFit, condType.toStr, boolType.toStr)
      successfulness = false

    self.pushScope()
    if not self.visit(elifThen):
      successfulness = false
    self.popScope()

  self.pushScope()
  if node.elseThen != nil and not self.visit(node.elseThen):
    successfulness = false
  self.popScope()

  return successfulness

proc visit*(self: Sema, node: Expr): Type =
  case node.kind
  of nkNumber: result = self.visit(Number(node))
  of nkBool:   result = self.visit(Bool(node))
  of nkSymbol: result = self.visit(Symbol(node))
  of nkBinary: result = self.visit(Binary(node))
  of nkUnary:  result = self.visit(Unary(node))
  else: result = newErrorType()

proc visit*(self: Sema, node: Stmt): bool =
  case node.kind
  of nkBlock:    result = self.visit(Block(node))
  of nkExprStmt: result = self.visit(ExprStmt(node))
  of nkDecl:     result = self.visit(Decl(node))
  of nkBranch:   result = self.visit(Branch(node))
  else: result = true
  