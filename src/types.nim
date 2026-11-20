import std/[sequtils, strutils, hashes]

type
  TypeKind* = enum
    typeNumberLit
    typeBoolLit
    typeInt
    typeBool
    typeVoid
    typeError
    typeMutable
    typeFunc

  Type* = object
    name*: string
    args*: seq[Type]
    case kind*: TypeKind
    of typeFunc:
      funcReturnType*: ref Type
      funcArgTypes*: seq[Type]
    else: discard

proc newNumberLitType*: Type =
  Type(name: "numberLiteral", args: @[], kind: typeNumberLit)

proc newBoolLitType*: Type =
  Type(name: "boolLiteral", args: @[], kind: typeBoolLit)

proc newIntType*: Type =
  Type(name: "int", args: @[], kind: typeInt)

proc newBoolType*: Type =
  Type(name: "bool", args: @[], kind: typeBool)

proc newVoidType*: Type =
  Type(name: "void", args: @[], kind: typeVoid)

proc newErrorType*: Type =
  Type(name: "error", args: @[], kind: typeError)

proc newMutableType*(typ: Type): Type =
  Type(name: "mutable", args: @[typ], kind: typeMutable)

proc newFuncType*(returnType: Type, argTypes: seq[Type]): Type =
  var ret = new(Type)
  ret[] = returnType
  Type(name: "func", args: @[], kind: typeFunc,
       funcReturnType: ret, funcArgTypes: argTypes)

proc toStr*(typ: Type): string =
  if typ.kind == typeFunc:
    var s = typ.funcReturnType[].toStr
    if typ.args.len > 0:
      s &= "[" & typ.args.mapIt(it.toStr).join(", ") & "]"
    s &= "(" & typ.funcArgTypes.mapIt(it.toStr).join(", ") & ")"
    s
  elif typ.args.len == 0:
    typ.name
  else:
    typ.name & "[" & typ.args.mapIt(it.toStr).join(", ") & "]"

proc hash*(typ: Type): Hash =
  result = hash(ord(typ.kind))
  case typ.kind
  of typeFunc:
    result = result !& hash(typ.funcReturnType[])
    for t in typ.funcArgTypes:
      result = result !& hash(t)
  else:
    result = result !& hash(typ.name)
  for t in typ.args:
    result = result !& hash(t)
  result = !$result
