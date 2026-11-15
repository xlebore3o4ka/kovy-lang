{.hint: "llvm codegen postponed for a while!".}

import ../[ast, types]
import ../parser/tokens
import llvnim
import llvnim/[idiomatic, dx]
import std/[tables]

# TODO (codegen)

# 1. Block: pushScope/popScope при входе/выходе (сейчас имена из вложенных блоков утекают в глобальный скоуп).
# 2. Sema: то же самое — pushScope/popScope в visit(Block) сейчас не вызываются.
# РЕШЕНО 3. Number: constInt(..., node.value.uint64, LLVMFalse) неверен для отрицательных — использовать cast[uint64] + signExtend, либо culonglong + (node.value < 0).
# РЕШЕНО 4. Binary(=): lvalueOf для вложенной Binary(=) должен звать visit (выполнять store), а не рекурсивно lvalueOf.
# РЕШЕНО 5. Binary(=): целевой LLVMTypeRef для buildIntCast2 брать из LLVMGetElementType(LLVMTypeOf(ptr)) (единообразно для Symbol и Binary(=)).
# РЕШЕНО 6. lvalueOf: вернуть nil/assert вместо raise при не-lvalue (чтобы не ронять компилятор). - Оставим raise, так как сема докажет, что все корректно
# РЕШЕНО 7. Binary: and/or — short-circuit через buildCondBr + два блока + phi.
# РЕШЕНО 8. main: создать i32 @main(), entry-блок, Block, buildRet(0).
# РЕШЕНО 9. alloca в entry-блоке: перепозиционировать builder на entry перед LLVMBuildAlloca (важно при if/while).
# РЕШЕНО 10. LLVMVerifyModule перед записью/исполнением.
# РЕШЕНО 11. Codegen: dispose (LLVMDisposeBuilder/Module/ContextDispose).
# РЕШЕНО 12. visitValue(Binary(=)) возвращает load (значение), не alloca/lvalue — разделение visitValue/lvalueOf реализовано.
# 13. Coercion: commonType/coerce для i32/u8/i64/... — приводить операнды Binary/Unary к общему типу (сейчас литералы уже i64, но при добавлении новых int-типов понадобится).

const
  # Names
  ProducerName* = "kovy"
  ModuleMainName* = "main"

  EntryBlockName* = "entry"
  AndRhsBlockName* = "and.rhs"
  AndEndBlockName* = "and.end"
  OrRhsBlockName*  = "or.rhs"
  OrEndBlockName*  = "or.end"

type
  Sym = object
    name: string
    typ: LLVMTypeRef
    value: LLVMValueRef

  Scope = ref object
    depth: Natural
    symbolTable: Table[string, Sym]
    case isGlobal: bool
    of false: parent: Scope
    of true: discard

  Codegen* = ref object
    ctx*: LLVMContextRef
    module*: LLVMModuleRef
    builder*: LLVMBuilderRef

    currentScope*: Scope
    symbolScopeStack*: Table[string, seq[Scope]]

    entryBB*: LLVMBasicBlockRef
    allocaInsertPt*: LLVMValueRef

proc getSymbol(self: Codegen, name: string): Sym =
  let scope = self.symbolScopeStack[name][^1]
  result = scope.symbolTable[name]

proc llvmTypeOf(self: Codegen, typ: Type): LLVMTypeRef =
  case typ.kind
  of typeInt:       int64TypeInContext(self.ctx)
  of typeBool:      int1TypeInContext(self.ctx)
  of typeMutable:   self.llvmTypeOf(typ.args[0])
  of typeNumberLit: int64TypeInContext(self.ctx)
  of typeBoolLit:   int1TypeInContext(self.ctx)
  of typeError:     raise newException(ValueError, "codegen reached error type")

proc newSymbol(self: Codegen, token: Token, typ: LLVMTypeRef, value: LLVMValueRef) =
  self.currentScope.symbolTable[token.lexeme] = Sym(name: token.lexeme, typ: typ, value: value)
  self.symbolScopeStack.mgetOrPut(token.lexeme, @[]).add(self.currentScope)

proc newCodegen*(moduleName, fileName, dir: string): Codegen =
  checkVersion()
  result = Codegen()
  result.ctx = contextCreate()
  result.module = moduleCreateWithNameInContext(moduleName, result.ctx)
  result.builder = createBuilderInContext(result.ctx)
  result.currentScope = Scope(isGlobal: true, symbolTable: initTable[string, Sym](), depth: 0)
  result.symbolScopeStack = initTable[string, seq[Scope]]()

proc visitValue*(self: Codegen, node: Expr): LLVMValueRef
proc visit*(self: Codegen, node: Stmt)

proc visitValue*(self: Codegen, node: Number): LLVMValueRef =
  constInt(int64TypeInContext(self.ctx),
    cast[uint64](node.value),
    if node.value < 0: LLVMTrue else: LLVMFalse)

proc visitValue*(self: Codegen, node: Bool): LLVMValueRef =
  constInt(int1TypeInContext(self.ctx), ord(node.value).uint64, LLVMFalse)

proc visitValue*(self: Codegen, node: Symbol): LLVMValueRef =
  load(self.builder, self.getSymbol(node.token.lexeme).value)

proc lvalueOf(self: Codegen, node: Expr): tuple[ptrr: LLVMValueRef, typ: LLVMTypeRef] =
  case node.kind
  of nkSymbol:
    let sym = self.getSymbol(Symbol(node).token.lexeme)
    return (sym.value, sym.typ)
  of nkBinary:
    let bin = Binary(node)
    if bin.token.kind == tkEquals:
      discard self.visitValue(bin)
      return self.lvalueOf(bin.lvalue)
    raise newException(ValueError, "not an lvalue: binary")
  else:
    raise newException(ValueError, "not an lvalue")

proc visitShortCircuit(self: Codegen, node: Binary): LLVMValueRef =
  let isAnd = node.token.kind == tkAnd
  let l = self.visitValue(node.lvalue)

  let fn = LLVMGetBasicBlockParent(LLVMGetInsertBlock(self.builder))
  let entryBB = LLVMGetInsertBlock(self.builder)
  let rhsName: cstring = cstring(if isAnd: AndRhsBlockName else: OrRhsBlockName)
  let endName: cstring = cstring(if isAnd: AndEndBlockName else: OrEndBlockName)
  let rhsBB = appendBasicBlockInContext(self.ctx, fn, rhsName)
  let endBB = appendBasicBlockInContext(self.ctx, fn, endName)

  if isAnd:
    discard buildCondBr(self.builder, l, rhsBB, endBB)
  else:
    discard buildCondBr(self.builder, l, endBB, rhsBB)

  positionBuilderAtEnd(self.builder, rhsBB)
  let r = self.visitValue(node.rvalue)
  let rhsEndBB = LLVMGetInsertBlock(self.builder)
  discard buildBr(self.builder, endBB)

  positionBuilderAtEnd(self.builder, endBB)
  let phi = LLVMBuildPhi(self.builder, LLVMTypeOf(l), "")
  var incomingVals = [l, r]
  var incomingBBs = [entryBB, rhsEndBB]
  LLVMAddIncoming(phi, addr incomingVals[0], addr incomingBBs[0], 2)
  return phi

proc visitValue*(self: Codegen, node: Binary): LLVMValueRef =
  if node.token.kind == tkEquals:
    let (ptrr, targetTyp) = self.lvalueOf(node.lvalue)
    var r = self.visitValue(node.rvalue)
    if LLVMTypeOf(r) != targetTyp:
      r = buildIntCast2(self.builder, r, targetTyp, LLVMTrue, "")
    discard store(self.builder, ptrr, r)
    return load(self.builder, ptrr)

  if node.token.kind in {tkAnd, tkOr}:
    return self.visitShortCircuit(node)

  let l = self.visitValue(node.lvalue)
  let r = self.visitValue(node.rvalue)

  case node.token.kind
  of tkPlus:  return buildAdd(self.builder, l, r, "")
  of tkMinus: return buildSub(self.builder, l, r, "")
  of tkStar:  return buildMul(self.builder, l, r, "")
  of tkSlash: return buildSDiv(self.builder, l, r, "")
  of tkGt:    return buildICmp(self.builder, LLVMIntSGT, l, r, "")
  of tkLt:    return buildICmp(self.builder, LLVMIntSLT, l, r, "")
  of tkGe:    return buildICmp(self.builder, LLVMIntSGE, l, r, "")
  of tkLe:    return buildICmp(self.builder, LLVMIntSLE, l, r, "")
  of tkEq:    return buildICmp(self.builder, LLVMIntEQ,  l, r, "")
  of tkNe:    return buildICmp(self.builder, LLVMIntNE,  l, r, "")
  else: raise newException(ValueError, "unexpected binary op: " & $node.token.kind)

proc visitValue*(self: Codegen, node: Unary): LLVMValueRef =
  let v = self.visitValue(node.value)
  case node.token.kind
  of tkPlus:  return v
  of tkMinus: return buildNeg(self.builder, v, "")
  of tkNot:   return buildNot(self.builder, v, "")
  else: raise newException(ValueError, "unexpected unary op: " & $node.token.kind)

proc visit*(self: Codegen, node: Block) =
  for stmt in node.stmts:
    self.visit(stmt)

proc visit*(self: Codegen, node: ExprStmt) =
  discard self.visitValue(node.expr)

proc visit*(self: Codegen, node: Decl) =
  let typ = self.llvmTypeOf(node.typ)

  let curBB = getInsertBlock(self.builder)
  if self.allocaInsertPt != nil:
    LLVMPositionBuilderBefore(self.builder, self.allocaInsertPt)
  else:
    positionBuilderAtEnd(self.builder, self.entryBB)

  let ptrr = alloca(self.builder, typ, node.token.lexeme)

  if self.allocaInsertPt == nil:
    self.allocaInsertPt = getFirstInstruction(self.entryBB)

  positionBuilderAtEnd(self.builder, curBB)

  self.newSymbol(node.token, typ, ptrr)

  if node.value != nil:
    var val = self.visitValue(node.value)
    if LLVMTypeOf(val) != typ:
      val = buildIntCast2(self.builder, val, typ, LLVMTrue, "")
    discard store(self.builder, ptrr, val)
  else:
    discard store(self.builder, ptrr, constInt(typ, 0'u64, false))

proc visitValue*(self: Codegen, node: Expr): LLVMValueRef =
  case node.kind
  of nkNumber: return self.visitValue(Number(node))
  of nkBool:   return self.visitValue(Bool(node))
  of nkSymbol: return self.visitValue(Symbol(node))
  of nkBinary: return self.visitValue(Binary(node))
  of nkUnary:  return self.visitValue(Unary(node))
  else: discard

proc visit*(self: Codegen, node: Stmt) =
  case node.kind
  of nkBlock:    self.visit(Block(node))
  of nkExprStmt: self.visit(ExprStmt(node))
  of nkDecl:     self.visit(Decl(node))
  else: discard

proc emit*(self: Codegen, node: Block): LLVMValueRef =
  let i32t = int32TypeInContext(self.ctx)
  let fnTy = functionType(i32t, [], false)
  let fn = addFunction(self.module, ModuleMainName, fnTy)

  let entryBB = appendBasicBlockInContext(self.ctx, fn, EntryBlockName)
  positionBuilderAtEnd(self.builder, entryBB)

  self.entryBB = entryBB
  self.allocaInsertPt = getFirstInstruction(entryBB)

  self.visit(node)
  discard buildRet(self.builder, constInt(i32t, 0'u64, LLVMFalse))

  if self.allocaInsertPt == nil:
    self.allocaInsertPt = LLVMGetFirstInstruction(self.entryBB)

  return fn

proc compileAndDump*(node: Stmt, moduleName = "kovy", filename, dir: string) =
  let cg = newCodegen(moduleName, filename, dir)
  defer:
    if cg.builder != nil: disposeBuilder(cg.builder)
    if cg.module  != nil: disposeModule(cg.module)
    if cg.ctx     != nil: LLVMContextDispose(cg.ctx)

  discard cg.emit(Block(node))

  let (ok, msg) = verifyModule(cg.module, 2)
  if not ok:
    raise newException(ValueError, "LLVM verifier failed:\n" & msg)
  dumpModule(cg.module)