import std/tables
import utils

tokenKinds:
  tkInvalid: "invalid token"
  tkEOF: "end of file"
  tkEOS: "end of statement"

  tkNumber: "number literal"
  tkIdent: "identifier"

  tkPlus: "plus operator '+'"
  tkMinus: "minus operator '-'"
  tkStar: "star operator '*'"
  tkSlash: "slash operator '/'"

  tkLParen: "left-paren '('"
  tkRParen: "right-paren ')'"

  tkComma: "comma ','"

  tkEquals: "equals operator '='"
  tkColon: "colon operator ':'"

  tkGt: "greater-than operator '>'"
  tkLt: "less-than operator '<'"
  tkGe: "greater-or-equal operator '>='"
  tkLe: "less-or-equal operator '<='"
  tkEq: "equality operator '=='"
  tkNe: "not-equal operator '!='"

  tkIndent: "indentation"
  tkDedent: "dedentation"

  tkInt: "keyword 'int'"
  tkBool: "keyword 'bool'"
  tkVoid: "keyword 'void'"

  tkTrue: "keyword 'true'"
  tkFalse: "keyword 'false'"

  tkNot: "keyword 'not'"
  tkOr: "keyword 'or'"
  tkAnd: "keyword 'and'"
  tkMut: "keyword 'mut'"
  tkIf: "keyword 'if'"
  tkElif: "keyword 'elif'"
  tkElse: "keyword 'else'"
  tkWhile: "keyword 'while'"
  tkBreak: "keyword 'break'"
  tkContinue: "keyword 'continue'"
  tkReturn: "keyword 'return'"

type
  Token* = object
    kind*: TokenKind
    lexeme*: string
    col*: Positive = 1
    line*: Positive = 1
    file*: Natural

proc mean*(t: Token): string = 
  let meaning = t.kind.mean()
  case t.kind:
  of tkNumber, tkIdent: meaning & " '" & t.lexeme & "'"
  else: meaning

var operatorsTable*: Table[string, TokenKind]
registerOp tkEOS,    ";"
registerOp tkPlus,   "+"
registerOp tkMinus,  "-"
registerOp tkStar,   "*"
registerOp tkSlash,  "/"
registerOp tkLParen, "("
registerOp tkRParen, ")"
registerOp tkComma,  ","
registerOp tkEquals, "="
registerOp tkGt,     ">"
registerOp tkLt,     "<"
registerOp tkGe,     ">="
registerOp tkLe,     "<="
registerOp tkEq,     "=="
registerOp tkNe,     "!="
registerOp tkColon,  ":"

var keywordsTable*: Table[string, TokenKind]
registerKw tkInt, "int"
registerKw tkBool, "bool"
registerKw tkVoid, "void"
registerKw tkTrue, "true"
registerKw tkFalse, "false"
registerKw tkNot, "not"
registerKw tkOr, "or"
registerKw tkAnd, "and"
registerKw tkMut, "mut"
registerKw tkIf, "if"
registerKw tkElif, "elif"
registerKw tkElse, "else"
registerKw tkWhile, "while"
registerKw tkBreak, "break"
registerKw tkContinue, "continue"
registerKw tkReturn, "return"

proc newToken*(kind: TokenKind, lexeme: string, line, col: Positive, file: Natural): Token =
  Token(kind: kind, lexeme: lexeme, file: file, line: line, col: col)