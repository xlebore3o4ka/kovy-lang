import std/[hashes, unittest]
import types

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