import std/[macros]

macro registerOp*(tk: untyped, op: string): untyped =
  quote do:
    operatorsTable[`op`] = `tk`

macro registerKw*(tk: untyped, op: string): untyped =
  quote do:
    keywordsTable[`op`] = `tk`

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