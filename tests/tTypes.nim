import std/[hashes, os, unittest]
import parser/[lexer, parser]
import errors
import ast
import types

const localePath =
  currentSourcePath().parentDir() / ".." / "src" / "error_locales" / "en.json"

proc parseTypeString(typeSource: string): Type =
  let source = typeSource & " value"
  let ctx = newErrorContext(localePath)
  let files = FileTracker()
  let lexer = newLexer(source, ctx, files.newFile("<test>", source))
  let parser = newParser(lexer, ctx)
  let tree = parser.parse()
  check ctx.errors.len == 0
  check tree.kind == nkBlock
  check Block(tree).stmts.len == 1
  check Block(tree).stmts[0].kind == nkDecl
  result = Decl(Block(tree).stmts[0]).typ

suite "types":
  test "primitive type names":
    check newIntType().toStr == "int"
    check newBoolType().toStr == "bool"
    check newVoidType().toStr == "void"
    check newNumberLitType().toStr == "numberLiteral"
    check newBoolLitType().toStr == "boolLiteral"
    check newErrorType().toStr == "error"

  test "mutable types wrap their argument":
    let typ = newMutableType(newIntType())
    check typ.kind == typeMutable
    check typ.args.len == 1
    check typ.args[0].toStr == "int"
    check typ.toStr == "mutable[int]"

  test "function types keep return and argument types":
    let typ = newFuncType(newVoidType(), @[newIntType(), newBoolType()])
    check typ.kind == typeFunc
    check typ.funcReturnType[].toStr == "void"
    check typ.funcArgTypes.len == 2
    check typ.funcArgTypes[0].toStr == "int"
    check typ.funcArgTypes[1].toStr == "bool"
    check typ.toStr == "void(int, bool)"

  test "sameType compares primitives":
    check sameType(newIntType(), newIntType())
    check sameType(newBoolType(), newBoolType())
    check not sameType(newIntType(), newBoolType())
    check not sameType(newIntType(), newNumberLitType())
    check not sameType(newErrorType(), newIntType())

  test "sameType compares mutable wrappers":
    check sameType(newMutableType(newIntType()),
                   newMutableType(newIntType()))
    check not sameType(newMutableType(newIntType()),
                       newMutableType(newBoolType()))
    check not sameType(newMutableType(newIntType()), newIntType())

  test "sameType compares function signatures":
    let first = newFuncType(newIntType(), @[newIntType(), newBoolType()])
    let same = newFuncType(newIntType(), @[newIntType(), newBoolType()])
    let otherArg = newFuncType(newIntType(), @[newBoolType(), newBoolType()])
    let otherReturn = newFuncType(newBoolType(), @[newIntType(), newBoolType()])
    let otherArity = newFuncType(newIntType(), @[newIntType()])

    check sameType(first, same)
    check not sameType(first, otherArg)
    check not sameType(first, otherReturn)
    check not sameType(first, otherArity)

  test "hash is stable for equal types":
    check hash(newIntType()) == hash(newIntType())
    check hash(newMutableType(newIntType())) ==
      hash(newMutableType(newIntType()))
    check hash(newFuncType(newIntType(), @[newBoolType()])) ==
      hash(newFuncType(newIntType(), @[newBoolType()]))

suite "function type syntax":
  test "function type without parameters":
    let typ = parseTypeString("void()")
    check typ.kind == typeFunc
    check typ.funcReturnType[].toStr == "void"
    check typ.funcArgTypes.len == 0
    check typ.toStr == "void()"

  test "function type with mutable and immutable parameters":
    let typ = parseTypeString("int(mut int, int)")
    check typ.kind == typeFunc
    check typ.funcReturnType[].toStr == "int"
    check typ.funcArgTypes.len == 2
    check typ.funcArgTypes[0].kind == typeMutable
    check typ.funcArgTypes[0].args[0].toStr == "int"
    check typ.funcArgTypes[1].toStr == "int"
    check typ.toStr == "int(mut int, int)"

  test "nested function types":
    let typ = parseTypeString("int(int(bool), mut void())")
    check typ.kind == typeFunc
    check typ.funcArgTypes.len == 2
    check typ.funcArgTypes[0].kind == typeFunc
    check typ.funcArgTypes[0].toStr == "int(bool)"
    check typ.funcArgTypes[1].kind == typeMutable
    check typ.funcArgTypes[1].args[0].toStr == "void()"
    check typ.toStr == "int(int(bool), mut void())"