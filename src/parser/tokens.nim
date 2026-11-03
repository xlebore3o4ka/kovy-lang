import std/[macros, tables]

macro registerOp(tk: untyped, op: string): untyped =
  quote do:
    operatorsTable[`op`] = `tk`

macro tokenKinds*(kinds: untyped): untyped =
  result = newNimNode(nnkStmtList)

  var enumTy = newNimNode(nnkEnumTy)
  enumTy.add(newEmptyNode())
  for kind in kinds:
    enumTy.add(kind[0])

  let typeName = newNimNode(nnkPostfix).add(
    newIdentNode("*"), newIdentNode("TokenKind")
  )
  let typeDef = newNimNode(nnkTypeDef).add(typeName, newEmptyNode(), enumTy)
  result.add(newNimNode(nnkTypeSection).add(typeDef))

  var caseStmt = newNimNode(nnkCaseStmt).add(newIdentNode("kind"))
  for kind in kinds:
    let ofBranch = newNimNode(nnkOfBranch)
    ofBranch.add(kind[0])
    ofBranch.add(newStrLitNode(kind[1][0].strVal))
    caseStmt.add(ofBranch)

  let formalParams = newNimNode(nnkFormalParams)
  formalParams.add(newIdentNode("string"))
  let paramGroup = newNimNode(nnkIdentDefs)
  paramGroup.add(newIdentNode("kind"), newIdentNode("TokenKind"), newEmptyNode())
  formalParams.add(paramGroup)

  let procDef = newNimNode(nnkProcDef).add(
    newNimNode(nnkPostfix).add(newIdentNode("*"), newIdentNode("mean")),
    newEmptyNode(),
    newEmptyNode(),
    formalParams,
    newNimNode(nnkPragma),
    newEmptyNode(),
    newNimNode(nnkStmtList).add(caseStmt)
  )
  result.add(procDef)

tokenKinds:
  tkEOF: "end of file"
  tkEOS: "end of statement"

  tkNumber: "number literal"

  tkPlus: "plus operator '+'"
  tkMinus: "minus operator '-'"
  tkStar: "star operator '*'"
  tkSlash: "slash operator '/'"

  tkLParen: "left-paren '('"
  tkRParen: "right-paren ')'"

  tkIndent: "indentation"
  tkDedent: "dedentation"

type
  Token* = object
    kind*: TokenKind
    lexeme*: string
    col*: Positive = 1
    line*: Positive = 1
    file*: Natural

template mean*(t: Token): string = t.kind.mean()

var operatorsTable*: Table[string, TokenKind]
registerOp tkEOS,    ";"
registerOp tkPlus,   "+"
registerOp tkMinus,  "-"
registerOp tkStar,   "*"
registerOp tkSlash,  "/"
registerOp tkLParen, "("
registerOp tkRParen, ")"

proc newToken*(kind: TokenKind, lexeme: string, line, col: Positive, file: Natural): Token =
  Token(kind: kind, lexeme: lexeme, file: file, line: line, col: col)