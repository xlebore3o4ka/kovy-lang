import std/[sequtils, strutils]

type
  TypeKind* = enum
    typeNumberLit
    typeBoolLit
    typeInt
    typeBool
    typeError
    typeMutable

  Type* = object
    name*: string
    args*: seq[Type]
    kind*: TypeKind

proc newNumberLitType*: Type =
  Type(name: "numberLiteral", args: @[], kind: typeNumberLit)

proc newBoolLitType*: Type =
  Type(name: "boolLiteral", args: @[], kind: typeBoolLit)

proc newIntType*: Type =
  Type(name: "int", args: @[], kind: typeInt)

proc newBoolType*: Type =
  Type(name: "bool", args: @[], kind: typeBool)

proc newErrorType*: Type =
  Type(name: "error", args: @[], kind: typeError)

proc newMutableType*(typ: Type): Type =
  Type(name: "mutable", args: @[typ], kind: typeMutable)

proc toStr*(typ: Type): string =
  if typ.args.len == 0:
    typ.name
  else:
    typ.name & "[" & typ.args.mapIt(it.toStr).join(", ") & "]"
