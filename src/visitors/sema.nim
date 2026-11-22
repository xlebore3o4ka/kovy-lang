import ../[ast, types, errors]
import ../parser/tokens
import std/[tables, strutils]

type
  Sym = object
    token: Token
    symbolType: Type
    scopeDepth: Natural

  Overload = ref object
    signature: Type
    decl: FuncDecl
    defined: bool
    overloadId: int

  Scope = ref object
    depth: Natural
    symbolTable: Table[string, Sym]
    case isGlobal: bool
    of false: parent: Scope
    of true: discard

  ContextScopeKind = enum
    cskBranch = "branch"
    cskLoop = "loop"
    cskFunc = "func"
    cskFuncArguments = "func-arguments"

  ContextScope = object
    case kind*: ContextScopeKind
    of cskFunc:
      funcReturnType*: Type
      funcArgsDepth*: Natural
    else: discard

  Sema* = ref object
    errors*: ErrorContext
    files: FileTracker

    currentScope: Scope
    symbolScopeStack: Table[string, seq[Scope]]
    contextScopeStack: seq[ContextScope]
    overloadTable: Table[string, seq[Overload]]
    forwardOrder: seq[Overload]
    nextOverloadId: int

proc newSema*(errors: ErrorContext, files: FileTracker = nil): Sema =
  Sema(errors: errors,
       files: files,
       currentScope: Scope(isGlobal: true, symbolTable: initTable[string, Sym](), depth: 0),
       overloadTable: initTable[string, seq[Overload]](),
       nextOverloadId: 1)

proc visit*(self: Sema, node: Expr): Type
proc visit*(self: Sema, node: Stmt): bool
proc controlAllReturnPaths(self: Sema, node: Stmt): bool

proc newSymbol(self: Sema, token: Token, typ: Type) =
  self.currentScope.symbolTable[token.lexeme] = Sym(token: token, symbolType: typ, 
    scopeDepth: self.currentScope.depth)
  self.symbolScopeStack.mgetOrPut(token.lexeme, @[]).add(self.currentScope)

proc pushScope(self: Sema, scope: ContextScope) =
  let depth = self.currentScope.depth
  self.currentScope = Scope(isGlobal: false, symbolTable: initTable[string, Sym](), 
    parent: self.currentScope, depth: depth + 1)
  self.contextScopeStack.add(scope)

proc popScope(self: Sema) =
  let scope = self.currentScope
  for name in scope.symbolTable.keys:
    discard self.symbolScopeStack[name].pop()
  self.currentScope = scope.parent
  discard self.contextScopeStack.pop()

proc isLoopContext(self: Sema): bool =
  for scope in self.contextScopeStack:
    if scope.kind == cskLoop:
      return true
  return false

proc isFuncContext(self: Sema): bool =
  for scope in self.contextScopeStack:
    if scope.kind == cskFunc:
      return true
  return false

proc getFuncContext(self: Sema): ContextScope =
  for i in countdown(self.contextScopeStack.high, 0):
    if self.contextScopeStack[i].kind == cskFunc:
      return self.contextScopeStack[i]
  return ContextScope()

proc symbolExists(self: Sema, name: string): bool =
  name in self.symbolScopeStack and self.symbolScopeStack[name].len > 0

proc getSymbol(self: Sema, name: string): Sym =
  let scope = self.symbolScopeStack[name][^1]
  result = scope.symbolTable[name]

proc getGlobalOverloads(self: Sema, name: string): seq[Overload] =
  # Only globally declared functions participate in overloading. A local
  # variable or nested function with the same name must keep the old Sym path.
  if name in self.overloadTable and self.symbolExists(name):
    let innermost = self.symbolScopeStack[name][^1]
    if innermost.isGlobal and self.getSymbol(name).symbolType.kind == typeFunc:
      return self.overloadTable[name]
  return @[]

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
  if expectedType.kind == typeMutable:
    return self.fits(typ, expectedType.args[0])
  expectedType.kind in fitSets.getOrDefault(typ.kind, {})

proc conversionCost(self: Sema, typ: Type, expectedType: Type): int =
  # -1 means "does not fit", 0 is an exact match, positive values are
  # conversions. This is call-site specific: unlike `fits`, it distinguishes a
  # mutable argument passed to a mut parameter from one passed by value.
  if typ.kind == typeError or expectedType.kind == typeError:
    return 0

  if expectedType.kind == typeMutable:
    if typ.kind != typeMutable:
      return -1
    return self.conversionCost(typ.args[0], expectedType.args[0])

  if typ.kind == typeMutable:
    let innerCost = self.conversionCost(typ.args[0], expectedType)
    if innerCost < 0:
      return -1
    return 1 + innerCost

  if sameType(typ, expectedType):
    return 0
  if self.fits(typ, expectedType):
    return 1
  return -1

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

proc newError(self: Sema, token: Token, kind: ErrorKind, placeholders: varargs[string, `$`]) =
  self.errors.add errors.newError(kind, token.file, token.line, token.col,
    token.lexeme.len, @placeholders)

proc sameParams(a, b: Type): bool =
  if a.kind != typeFunc or b.kind != typeFunc:
    return false
  if a.funcArgTypes.len != b.funcArgTypes.len:
    return false
  for i in 0 ..< a.funcArgTypes.len:
    if not sameType(a.funcArgTypes[i], b.funcArgTypes[i]):
      return false
  return true

proc findOverload(overloads: seq[Overload], funcType: Type): int =
  for i, overload in overloads:
    if sameParams(overload.signature, funcType):
      return i
  return -1

proc overloadListLine(self: Sema, overload: Overload): string =
  let decl = overload.decl
  var args: seq[string]
  for arg in decl.arguments:
    args.add((if arg.mut: "mut " else: "") & arg.typ.toStr)
  let file =
    if self.files != nil: self.files.uninternFile(decl.token.file)
    else: $decl.token.file
  file & " " & $decl.token.line & " - " &
    (if decl.mut: "mut " else: "") & decl.returnType.toStr & " " &
    decl.token.lexeme & "(" & args.join(", ") & ")"

proc overloadList(self: Sema, overloads: seq[Overload]): string =
  var lines: seq[string]
  for overload in overloads:
    lines.add self.overloadListLine(overload)
  lines.join("\n  ")

proc rejectNonFunctionName(self: Sema, node: Node, name: string): bool =
  if self.symbolExists(name):
    let sym = self.getSymbol(name)
    if sym.symbolType.kind != typeFunc:
      self.newError(node, errRedeclaration, name, sym.token.file, sym.token.line)
      return true
  return false

proc diagnosticTypeStr(typ: Type): string =
  if typ.kind == typeMutable:
    "mut " & diagnosticTypeStr(typ.args[0])
  else:
    typ.toStr

proc visit*(self: Sema, node: Number): Type =
  return newNumberLitType()

proc visit*(self: Sema, node: Bool): Type =
  return newBoolLitType()

proc visit*(self: Sema, node: Symbol): Type =
  let name = node.token.lexeme
  if not self.symbolExists(name):
    self.newError(node, errUnknownSymbol, name, self.suggestName(name))
    return newErrorType()

  return self.getSymbol(name).symbolType

proc visit*(self: Sema, node: Binary): Type =
  let ltype = self.visit(node.lvalue)
  let rtype = self.visit(node.rvalue)
  self.handleErrorType(ltype, rtype)

  if node.token.kind == tkEquals:
    if ltype.kind != typeMutable:
      self.newError(node, errImmutableAssignment, node.lvalue.toStr(), ltype.toStr())
      return newErrorType()
    let inner = ltype.args[0]
    if not self.fits(rtype, inner):
      self.newError(node, errBinaryMismatch, node.token.mean(), inner.toStr & " " & node.token.lexeme & " " & rtype.toStr)
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

proc resolveOverloadCall(self: Sema, node: Call,
    overloads: seq[Overload]): Type =
  var argTypes: seq[Type]
  for a in node.arguments:
    let t = self.visit(a)
    if t.kind == typeError:
      return newErrorType()
    argTypes.add t

  var candidates: seq[Overload]
  var bestCost = high(int)
  for overload in overloads:
    let signature = overload.signature
    if argTypes.len != signature.funcArgTypes.len:
      continue

    var totalCost = 0
    var matched = true
    for i in 0 ..< argTypes.len:
      let cost = self.conversionCost(argTypes[i], signature.funcArgTypes[i])
      if cost < 0:
        matched = false
        break
      totalCost += cost

    if not matched:
      continue

    if totalCost < bestCost:
      bestCost = totalCost
      candidates = @[overload]
    elif totalCost == bestCost:
      candidates.add overload

  var argsStr = ""
  for i, typ in argTypes:
    if i > 0:
      argsStr.add ", "
    argsStr.add diagnosticTypeStr(typ)

  let name = Symbol(node.value).token.lexeme

  if candidates.len == 1:
    node.resolvedOverloadId = candidates[0].overloadId
    node.isVoidCall = candidates[0].signature.funcReturnType[].kind == typeVoid
    return candidates[0].signature.funcReturnType[]
  elif candidates.len > 1:
    self.newError(node, errAmbiguousCall, name, argsStr,
      self.overloadList(candidates))
    return newErrorType()
  else:
    self.newError(node, errNoMatchingOverload, name, argsStr,
      self.overloadList(overloads))
    return newErrorType()

proc visit*(self: Sema, node: Call): Type =
  var overloads: seq[Overload]
  if node.value.kind == nkSymbol:
    overloads = self.getGlobalOverloads(Symbol(node.value).token.lexeme)
    if overloads.len > 1:
      return self.resolveOverloadCall(node, overloads)

  let callee = self.visit(node.value)
  self.handleErrorType(callee)

  var argTypes: seq[Type]
  for a in node.arguments:
    let t = self.visit(a)
    self.handleErrorType(t)
    argTypes.add t

  if callee.kind != typeFunc:
    self.newError(node.value, errNotCallable, node.value.toStr)
    return newErrorType()

  if argTypes.len != callee.funcArgTypes.len:
    self.newError(node, errWrongArity, $argTypes.len, $callee.funcArgTypes.len)
    return newErrorType()

  for i in 0 ..< callee.funcArgTypes.len:
    if self.conversionCost(argTypes[i], callee.funcArgTypes[i]) < 0:
      let arg = node.arguments[i]
      self.newError(arg, errArgMismatch, arg.toStr,
                   diagnosticTypeStr(argTypes[i]),
                   diagnosticTypeStr(callee.funcArgTypes[i]))
      return newErrorType()

  if overloads.len == 1:
    node.resolvedOverloadId = overloads[0].overloadId

  node.isVoidCall = callee.funcReturnType[].kind == typeVoid
  return callee.funcReturnType[]

proc visit*(self: Sema, node: Block): bool =
  var unreachableFounder: Stmt
  var fromLine, toLine: Natural
  var hasUnreachableCode: bool

  for stmt in node.stmts:
    if unreachableFounder != nil:
      hasUnreachableCode = true
      toLine = stmt.token.line

    discard self.visit(stmt)

    if unreachableFounder == nil and self.controlAllReturnPaths(stmt):
      unreachableFounder = stmt
      fromLine = stmt.token.line + 1

  if hasUnreachableCode:
    self.newError(unreachableFounder, errUnreachableCode, fromLine, toLine)

  return true

proc visit*(self: Sema, node: ExprStmt): bool =
  self.manageErrorType(self.visit(node.expr))
  return true

proc visit*(self: Sema, node: Decl): bool =
  let expectedType = node.typ
  let symbolType = if node.mut: newMutableType(expectedType) else: expectedType
  var successfulness = true

  # Source order matters, because an initializer may reference a name declared
  # earlier on the same line.
  for entry in node.declEntries:
    if entry.value != nil:
      let typ = self.visit(entry.value)
      if typ.kind == typeError:
        successfulness = false

      if not self.fits(typ, expectedType):
        self.newError(entry.value, errDoesNotFit, typ.toStr, expectedType.toStr)
        successfulness = false

    if self.symbolExistsInScope(entry.name):
      let sym = self.getSymbol(entry.name)
      let file = sym.token.file
      let line = sym.token.line
      self.newError(entry.token, errRedeclaration, entry.name, file, line)
      successfulness = false

    self.newSymbol(entry.token, symbolType)

  return successfulness

proc visit*(self: Sema, node: Branch): bool =
  let condType = self.visit(node.cond)
  let boolType = newBoolType()

  result = true

  if not self.fits(condType, boolType):
    self.newError(node, errDoesNotFit, condType.toStr, boolType.toStr)
    result = false

  self.pushScope(ContextScope(kind: cskBranch))
  if not self.visit(node.ifThen):
    result = false
  self.popScope()

  for (cond, elifThen) in node.elifs:
    let condType = self.visit(cond)

    if not self.fits(condType, boolType):
      self.newError(node, errDoesNotFit, condType.toStr, boolType.toStr)
      result = false

    self.pushScope(ContextScope(kind: cskBranch))
    if not self.visit(elifThen):
      result = false
    self.popScope()

  self.pushScope(ContextScope(kind: cskBranch))
  if node.elseThen != nil and not self.visit(node.elseThen):
    result = false
  self.popScope()

proc visit*(self: Sema, node: While): bool =
  let condType = self.visit(node.cond)
  let boolType = newBoolType()

  result = true

  if not self.fits(condType, boolType):
    self.newError(node, errDoesNotFit, condType.toStr, boolType.toStr)
    result = false

  self.pushScope(ContextScope(kind: cskLoop))
  if not self.visit(node.body):
    result = false
  self.popScope()

proc visit*(self: Sema, node: Break): bool =
  if not self.isLoopContext():
    self.newError(node, errContextScope, node.token.lexeme, cskLoop)
    return false
  return true

proc visit*(self: Sema, node: Continue): bool =
  if not self.isLoopContext():
    self.newError(node, errContextScope, node.token.lexeme, cskLoop)
    return false
  return true

proc exitsLoop(node: Stmt): bool =
  case node.kind
  of nkBreak:
    return true
  of nkBlock:
    for stmt in Block(node).stmts:
      if exitsLoop(stmt):
        return true
    return false
  of nkBranch:
    let branch = Branch(node)
    if exitsLoop(branch.ifThen):
      return true
    for (_, elifThen) in branch.elifs:
      if exitsLoop(elifThen):
        return true
    return branch.elseThen != nil and exitsLoop(branch.elseThen)
  # A break in a nested loop belongs to that loop, and a nested function has
  # its own loop context.
  of nkWhile, nkFuncDecl:
    return false
  else:
    return false

proc controlAllReturnPaths(self: Sema, node: Stmt): bool =
  case node.kind
  of nkBlock:
    for stmt in Block(node).stmts:
      if self.controlAllReturnPaths(stmt):
        return true
    return false
  of nkReturn:
    return true
  of nkBranch:
    let branch = Branch(node)
    if branch.elseThen == nil:
      return false
    if not self.controlAllReturnPaths(branch.ifThen):
      return false
    for (_, elifThen) in branch.elifs:
      if not self.controlAllReturnPaths(elifThen):
        return false
    return self.controlAllReturnPaths(branch.elseThen)
  of nkWhile:
    let loop = While(node)
    # `while true` never falls through unless a break can leave the loop.
    return loop.cond.kind == nkBool and Bool(loop.cond).value and
      not exitsLoop(loop.body)
  else:
    return false

proc sameParamNames(a, b: FuncDecl): bool =
  # Nim resolves a forward declaration and its definition as one proc only when
  # the parameter names match; otherwise they become two overloads.
  if a.arguments.len != b.arguments.len:
    return false
  for i in 0 ..< a.arguments.len:
    if a.arguments[i].token.lexeme != b.arguments[i].token.lexeme:
      return false
  return true

proc signatureStr(decl: FuncDecl): string =
  var args: seq[string]
  for arg in decl.arguments:
    args.add((if arg.mut: "mut " else: "") & arg.typ.toStr & " " &
      arg.token.lexeme)
  (if decl.mut: "mut " else: "") & decl.returnType.toStr & " " &
    decl.token.lexeme & "(" & args.join(", ") & ")"

proc visit*(self: Sema, node: FuncDecl): bool =
  var argTypes: seq[Type]

  for decl in node.arguments:
    for entry in decl.declEntries:
      if entry.value != nil:
        self.newError(entry.token, errDefaultForbidden, entry.name)
        # Defaults are forbidden, so treat the parameter as required from here on.
        # This also keeps the rest of the pipeline free of cascading errors and
        # prevents default values from leaking into codegen.
        decl.decls[entry.name].value = nil
    argTypes.add(if decl.mut: newMutableType(decl.typ) else: decl.typ)

  let returnType =
    if node.mut: newMutableType(node.returnType)
    else: node.returnType

  let funcType = newFuncType(returnType, argTypes)
  let name = node.token.lexeme

  result = true

  if node.body == nil and not self.currentScope.isGlobal:
    self.newError(node, errForwardOutsideGlobal, name)
    return false

  if self.currentScope.isGlobal:
    if self.rejectNonFunctionName(node, name):
      return false

    let existing = self.overloadTable.getOrDefault(name, @[])
    let index = findOverload(existing, funcType)

    if node.body == nil:
      if index >= 0:
        let overload = existing[index]
        if sameType(overload.signature.funcReturnType[],
            funcType.funcReturnType[]):
          self.newError(node, errFuncRedefinition, name)
        else:
          self.newError(node, errOverloadByReturnType, name,
            signatureStr(overload.decl), signatureStr(node))
        return false

      if existing.len == 0 and self.symbolExists(name):
        self.newError(node, errFuncRedefinition, name)
        return false

      let overload = Overload(signature: funcType, decl: node, defined: false,
        overloadId: self.nextOverloadId)
      inc self.nextOverloadId

      node.overloadId = overload.overloadId
      if existing.len == 0:
        self.newSymbol(node.token, funcType)
      self.overloadTable.mgetOrPut(name, @[]).add overload
      self.forwardOrder.add overload

      # Parameters of a forward declaration still have to be validated (default
      # values in particular), even though their scope is discarded immediately.
      self.pushScope(ContextScope(kind: cskFuncArguments))
      for decl in node.arguments:
        if not self.visit(decl):
          result = false
      self.popScope()
      return result

    if index >= 0:
      let overload = existing[index]

      if overload.defined:
        if sameType(overload.signature.funcReturnType[],
            funcType.funcReturnType[]):
          self.newError(node, errFuncRedefinition, name)
        else:
          self.newError(node, errOverloadByReturnType, name,
            signatureStr(overload.decl), signatureStr(node))
        return false

      if not sameType(overload.signature, funcType) or
          not sameParamNames(overload.decl, node):
        self.newError(node, errFuncSignatureMismatch, name,
          signatureStr(overload.decl), signatureStr(node))
        # A definition was found, it just does not match; do not report the same
        # forward again as unresolved during finalize.
        overload.defined = true
        return false

      overload.defined = true
      overload.decl = node
      node.overloadId = overload.overloadId

      # The symbol was already registered by the forward declaration; re-adding
      # it would push the scope twice into symbolScopeStack.
      var sym = self.currentScope.symbolTable[name]
      sym.token = node.token
      self.currentScope.symbolTable[name] = sym
    else:
      if existing.len == 0 and self.symbolExists(name):
        self.newError(node, errFuncRedefinition, name)
        return false

      let overload = Overload(signature: funcType, decl: node, defined: true,
        overloadId: self.nextOverloadId)
      inc self.nextOverloadId

      node.overloadId = overload.overloadId
      if existing.len == 0:
        self.newSymbol(node.token, funcType)
      self.overloadTable.mgetOrPut(name, @[]).add overload
  else:
    # Nested functions are allowed but cannot be overloaded.
    if self.rejectNonFunctionName(node, name):
      return false
    if self.symbolExists(name):
      self.newError(node, errFuncRedefinition, name)
      return false

    self.newSymbol(node.token, funcType)

  self.pushScope(ContextScope(kind: cskFuncArguments))

  for decl in node.arguments:
    if not self.visit(decl):
      result = false

  if not result:
    return false

  let funcArgsDepth = self.currentScope.depth
  self.pushScope(ContextScope(kind: cskFunc, funcReturnType: returnType,
    funcArgsDepth: funcArgsDepth))

  if not self.visit(node.body):
    result = false

  self.popScope()
  self.popScope()

  if node.body != nil and node.returnType.kind != typeVoid and
      not self.controlAllReturnPaths(node.body):
    self.newError(node, errNotAllPathsReturn)
    result = false

proc finalize*(self: Sema) =
  for overload in self.forwardOrder:
    if not overload.defined:
      self.newError(overload.decl, errUnresolvedForward,
        overload.decl.token.lexeme)

proc getMutabilitySource(self: Sema, node: Expr): Sym =
  case node.kind
  of nkBinary: return self.getMutabilitySource(Binary(node).lvalue)
  of nkCall:   return self.getMutabilitySource(Call(node).value)
  of nkSymbol: return self.getSymbol(node.token.lexeme)
  else:        raise newException(Exception, "A mutable expression cannot be generated by a non-symbol")

proc visit*(self: Sema, node: Return): bool =
  result = true
  
  if not self.isFuncContext():
    self.newError(node, errContextScope, node.token.lexeme, cskFunc)
    return false

  let context = self.getFuncContext() 

  if node.value != nil:
    let t = self.visit(node.value)
    self.manageErrorType(t)

    if context.funcReturnType.kind == typeVoid:
      self.newError(node, errVoidReturnValue)
      return false

    elif context.funcReturnType.kind == typeMutable and t.kind != typeMutable:
      self.newError(node, errImmutableReturn)
      return false

    elif not self.fits(t, context.funcReturnType):
      self.newError(node, errDoesNotFit, t.toStr, context.funcReturnType.toStr)
      return false

    if t.kind == typeMutable and context.funcReturnType.kind == typeMutable:
      let s = self.getMutabilitySource(node.value)

      if s.scopeDepth > context.funcArgsDepth:
        self.newError(node, errReturnDanglingMutable, s.token.lexeme,
          s.token.file, s.token.line)
        return false

  elif context.funcReturnType.kind != typeVoid:
    self.newError(node, errReturnValueExpected, context.funcReturnType.toStr)
    return false

proc visit*(self: Sema, node: Expr): Type =
  case node.kind
  of nkNumber: result = self.visit(Number(node))
  of nkBool:   result = self.visit(Bool(node))
  of nkSymbol: result = self.visit(Symbol(node))
  of nkBinary: result = self.visit(Binary(node))
  of nkUnary:  result = self.visit(Unary(node))
  of nkCall:   result = self.visit(Call(node))
  else: result = newErrorType()

proc visit*(self: Sema, node: Stmt): bool =
  case node.kind
  of nkBlock:    result = self.visit(Block(node))
  of nkExprStmt: result = self.visit(ExprStmt(node))
  of nkDecl:     result = self.visit(Decl(node))
  of nkBranch:   result = self.visit(Branch(node))
  of nkWhile:    result = self.visit(While(node))
  of nkBreak:    result = self.visit(Break(node))
  of nkContinue: result = self.visit(Continue(node))
  of nkFuncDecl: result = self.visit(FuncDecl(node))
  of nkReturn:   result = self.visit(Return(node))
  else: result = true
  