import parser/tokens
import std/strutils

type
  NodeKind* = enum
    nkInvalid
    nkNumber
    nkBinary
    nkUnary

  Node* = ref object of RootObj
    kind*: NodeKind
    token*: Token

  Expr* = ref object of Node

  Invalid* = ref object of Expr
  Number* = ref object of Expr
    value*: int
  Binary* = ref object of Expr
    lvalue*: Expr
    rvalue*: Expr
  Unary* = ref object of Expr
    value*: Expr

proc newInvalid*(token: Token): Invalid =
  Invalid(kind: nkInvalid, token: token)

proc newNumber*(token: Token): Number =
  Number(kind: nkNumber, token: token, value: parseInt(token.lexeme))

proc newBinary*(token: Token, lvalue, rvalue: Expr): Binary =
  Binary(kind: nkBinary, token: token, lvalue: lvalue, rvalue: rvalue)

proc newUnary*(token: Token, value: Expr): Unary =
  Unary(kind: nkUnary, token: token, value: value)

proc toStr*(node: Node, depth: Natural = 0): string =
  let indent = repeat(' ', depth * 2)
  case node.kind
  of nkInvalid:
    indent & "Invalid"
  of nkNumber:
    indent & "Number " & $Number(node).value
  of nkBinary:
    indent & "Binary " & node.token.lexeme & "\n" &
      toStr(Binary(node).lvalue, depth + 1) & "\n" &
      toStr(Binary(node).rvalue, depth + 1)
  of nkUnary:
    indent & "Unary " & node.token.lexeme & "\n" &
      toStr(Unary(node).value, depth + 1)