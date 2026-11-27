import std/[algorithm, json, os, sequtils, sets, strutils, tables]
import parser/[lexer, parser, tokens]
import errors
import ast
import types
import visitors/[sema, nimgen]

const
  LocalePath = "src/error_locales/en.json"
  DocsRoot = "docs"
  ErrorsRoot = DocsRoot / "errors"

type
  DocSnippet = object
    where: string
    expected: seq[string]
    source: string

var failures: seq[string]

proc fail(message: string) =
  failures.add message
  echo "FAIL: ", message

proc readText(path: string): string =
  if not fileExists(path):
    fail("missing file: " & path)
    return ""
  readFile(path)

proc strippedFences(source: string): string =
  ## Remove fenced code blocks so anchors and links inside examples are not
  ## treated as real document structure.
  var inFence = false
  for line in source.splitLines():
    if line.strip().startsWith("```"):
      inFence = not inFence
      result.add '\n'
    elif not inFence:
      result.add line
      result.add '\n'

proc anchorsIn(source: string): seq[string] =
  let text = strippedFences(source)
  var i = 0
  while true:
    let start = text.find("<a id=\"", i)
    if start < 0:
      break
    let finish = text.find("\"></a>", start + 7)
    if finish < 0:
      break
    result.add text[start + 7 ..< finish]
    i = finish + 6

proc metadata(source, key: string): string =
  let text = strippedFences(source)
  let marker = "<!-- " & key & ": "
  let start = text.find(marker)
  if start < 0:
    return ""
  let finish = text.find(" -->", start + marker.len)
  if finish < 0:
    return ""
  text[start + marker.len ..< finish]

proc linksIn(source: string): seq[string] =
  let text = strippedFences(source)
  var i = 0
  while true:
    let start = text.find("](", i)
    if start < 0:
      break
    let finish = text.find(")", start + 2)
    if finish < 0:
      break
    var target = text[start + 2 ..< finish].strip()
    if target.len >= 2 and target[0] == '<' and target[^1] == '>':
      target = target[1 .. ^2]
    result.add target
    i = finish + 1

proc placeholderTokens(text: string): seq[string] =
  var i = 0
  while i < text.len:
    if text[i] != '@':
      inc i
      continue
    var j = i + 1
    while j < text.len and text[j] in {'q', 'c', 'f', 'n', '0'..'9'}:
      inc j
    var hasDigit = false
    for k in i + 1 ..< j:
      if text[k] in {'0'..'9'}:
        hasDigit = true
    if hasDigit:
      result.add text[i ..< j]
    i = j

proc markdownFiles(root: string): seq[string] =
  for path in walkDirRec(root):
    if path.endsWith(".md"):
      result.add path
  result.sort()

proc rowsFor(content, kind: string): seq[seq[string]] =
  for line in content.splitLines():
    let stripped = line.strip()
    if stripped.startsWith("| `" & kind & "`"):
      let row = stripped.split('|')
      # Ignore coverage rows outside the error table, such as the nimgen
      # concern row that also starts with an error-kind name.
      if row.len >= 5:
        result.add row

proc cell(row: seq[string], index: int): string =
  if index < row.len:
    row[index].strip()
  else:
    ""

proc snippetList(content, where: string): seq[DocSnippet] =
  let lines = content.splitLines()
  var i = 0
  while i < lines.len:
    let marker = "<!-- expect-errors:"
    let start = lines[i].find(marker)
    if start >= 0:
      let finish = lines[i].find("-->", start + marker.len)
      if finish < 0:
        fail(where & ":" & $(i + 1) & ": unterminated expect-errors marker")
      else:
        let payload = lines[i][start + marker.len ..< finish].strip()
        var expected: seq[string]
        if payload.len > 0 and payload != "OK":
          for part in payload.split(','):
            let item = part.strip()
            if item.len > 0:
              expected.add item
        var j = i + 1
        while j < lines.len and not lines[j].strip().startsWith("```kovy"):
          inc j
        if j >= lines.len:
          fail(where & ":" & $(i + 1) &
            ": expect-errors marker is not followed by a kovy fence")
        else:
          inc j
          var source = ""
          var first = true
          var closed = false
          while j < lines.len:
            if lines[j].strip().startsWith("```"):
              closed = true
              break
            if not first:
              source.add '\n'
            source.add lines[j]
            first = false
            inc j
          if not closed:
            fail(where & ":" & $(i + 1) & ": unterminated kovy fence")
          else:
            result.add DocSnippet(where: where & ":" & $(i + 1),
                                  expected: expected, source: source)
            i = j
    inc i

proc analyze(source: string): seq[ErrorKind] =
  let ctx = newErrorContext(LocalePath)
  let files = FileTracker()
  let lexer = newLexer(source, ctx, files.newFile("<docs>", source))
  let parser = newParser(lexer, ctx)
  let tree = parser.parse()

  let sema = newSema(ctx, files)
  discard sema.visit(tree)
  sema.finalize()

  result = ctx.errors.mapIt(it.kind)
  if result.len == 0:
    discard newNimgen(ctx).emit(tree)
    result = ctx.errors.mapIt(it.kind)

proc kindNames(): seq[string] =
  for kind in ErrorKind:
    result.add $kind

proc parserProductions(source: string): HashSet[string] =
  result = initHashSet[string]()
  for line in source.splitLines():
    let stripped = line.strip()
    if not stripped.startsWith("proc parse"):
      continue
    var name = ""
    var i = len("proc ")
    while i < stripped.len and stripped[i] notin {'*', '(', ':'}:
      name.add stripped[i]
      inc i
    if name.len > 0:
      result.incl name

proc sourceErrorNames(source: string): HashSet[string] =
  result = initHashSet[string]()
  var i = 0
  while true:
    let start = source.find("err", i)
    if start < 0:
      break
    if start + 3 < source.len and source[start + 3] in {'A'..'Z'}:
      var finish = start + 3
      while finish < source.len and
          source[finish] in {'A'..'Z', 'a'..'z', '0'..'9', '_'}:
        inc finish
      result.incl source[start ..< finish]
    i = start + 3

proc checkTable(path, content, kind, expectedStatus, linkSuffix: string) =
  let rows = rowsFor(content, kind)
  if rows.len != 1:
    fail(path & ": expected exactly one row for " & kind & ", found " & $rows.len)
    return
  let row = rows[0]
  if cell(row, 2).len == 0:
    fail(path & ": empty phase for " & kind)
  if cell(row, 3) != expectedStatus:
    fail(path & ": status for " & kind & " is '" & cell(row, 3) &
      "', expected '" & expectedStatus & "'")
  var hasLink = false
  for column in row:
    if column.contains(linkSuffix):
      hasLink = true
  if not hasLink:
    fail(path & ": row for " & kind & " does not link to " & linkSuffix)

proc countErrorRows(content: string): int =
  for line in content.splitLines():
    if line.strip().startsWith("| `err") and line.count('|') >= 5:
      inc result

proc main() =
  let kinds = kindNames()
  let kindSet = kinds.toHashSet()

  # Locale inventory -------------------------------------------------------
  var locale: JsonNode
  if not fileExists(LocalePath):
    fail("missing locale file: " & LocalePath)
  else:
    try:
      locale = parseFile(LocalePath)
    except CatchableError as exc:
      fail("cannot parse locale file: " & exc.msg)

  var localeKinds: HashSet[string]
  if locale != nil:
    localeKinds = initHashSet[string]()
    for key, value in locale.pairs:
      if key.startsWith("err") and value.kind == JObject:
        localeKinds.incl key
    for kind in kinds:
      if kind notin localeKinds:
        fail("locale has no entry for " & kind)
    for kind in localeKinds:
      if kind notin kindSet:
        fail("locale has an entry for unknown kind " & kind)

  # Source emitter inventory ----------------------------------------------
  const sourceFiles = [
    "src/parser/lexer.nim",
    "src/parser/parser.nim",
    "src/visitors/sema.nim",
    "src/visitors/nimgen.nim",
  ]

  var sourceKinds = initHashSet[string]()
  for path in sourceFiles:
    let text = readText(path)
    for name in sourceErrorNames(text):
      if name.len > 3:
        sourceKinds.incl name

  for name in sourceKinds:
    if name notin kindSet:
      fail("source mentions unknown error identifier " & name)
  if "errIllformedArgument" in sourceKinds:
    fail("errIllformedArgument is marked declared-not-emitted but appears in source")
  for kind in kinds:
    if kind != "errIllformedArgument" and kind notin sourceKinds:
      fail("emitted kind " & kind & " is not mentioned in any compiler source file")

  # Error pages ------------------------------------------------------------
  let coverage = readText(DocsRoot / "_meta" / "coverage.md")
  let errorIndex = readText(ErrorsRoot / "index.md")
  let referenceIndex = readText(DocsRoot / "reference" / "error-index.md")

  if countErrorRows(coverage) != kinds.len:
    fail("coverage.md has " & $countErrorRows(coverage) &
      " error rows, expected " & $kinds.len)
  if countErrorRows(errorIndex) != kinds.len:
    fail("errors/index.md has " & $countErrorRows(errorIndex) &
      " error rows, expected " & $kinds.len)
  if countErrorRows(referenceIndex) != kinds.len:
    fail("reference/error-index.md has " & $countErrorRows(referenceIndex) &
      " error rows, expected " & $kinds.len)

  var pageFiles: seq[string]
  if dirExists(ErrorsRoot):
    for path in walkDirRec(ErrorsRoot):
      if path.endsWith(".md"):
        let name = path.extractFilename()
        if name.startsWith("err"):
          pageFiles.add name[0 ..< name.len - 3]
  pageFiles.sort()
  var expectedPages = kinds
  expectedPages.sort()
  if pageFiles != expectedPages:
    fail("error page set does not match ErrorKind set; pages=" & $pageFiles.len &
      ", kinds=" & $kinds.len)
    for kind in expectedPages:
      if kind notin pageFiles:
        fail("missing error page for " & kind)
    for page in pageFiles:
      if page notin expectedPages:
        fail("extra error page for unknown kind " & page)

  for kind in kinds:
    let path = ErrorsRoot / (kind & ".md")
    let page = readText(path)
    if page.len == 0:
      continue

    let expectedStatus =
      if kind == "errIllformedArgument": "declared-not-emitted"
      else: "emitted"

    if metadata(page, "kind") != kind:
      fail(path & ": kind metadata is '" & metadata(page, "kind") &
        "', expected '" & kind & "'")
    if metadata(page, "doc-id") != "ERR-" & kind:
      fail(path & ": doc-id metadata is '" & metadata(page, "doc-id") &
        "', expected 'ERR-" & kind & "'")
    if metadata(page, "status") != expectedStatus:
      fail(path & ": status metadata is '" & metadata(page, "status") &
        "', expected '" & expectedStatus & "'")
    if metadata(page, "phase").len == 0:
      fail(path & ": missing phase metadata")

    let pageAnchors = anchorsIn(page)
    if "ERR-" & kind notin pageAnchors:
      fail(path & ": missing anchor ERR-" & kind)
    let triggerPrefix = "TRG-" & kind & "-"
    let triggers = pageAnchors.filterIt(it.startsWith(triggerPrefix))
    if expectedStatus == "emitted" and triggers.len == 0:
      fail(path & ": emitted kind has no TRG-* section")
    if expectedStatus == "declared-not-emitted" and triggers.len != 0:
      fail(path & ": declared-not-emitted kind has " & $triggers.len &
        " TRG-* section(s)")

    if locale != nil and locale.hasKey(kind):
      let data = locale[kind]
      let message = data{"message"}.getStr("")
      let addinfo = data{"addinfo"}.getStr("")
      if message.len > 0 and not page.contains(message):
        fail(path & ": does not contain exact locale message: " & message)
      if addinfo.len > 0 and not page.contains(addinfo):
        fail(path & ": does not contain exact locale addinfo: " & addinfo)
      for token in placeholderTokens(message & " " & addinfo):
        if not page.contains(token):
          fail(path & ": does not mention placeholder " & token)

    checkTable(DocsRoot / "_meta" / "coverage.md", coverage, kind,
      expectedStatus, kind & ".md#ERR-" & kind)
    checkTable(ErrorsRoot / "index.md", errorIndex, kind,
      expectedStatus, kind & ".md#ERR-" & kind)
    checkTable(DocsRoot / "reference" / "error-index.md", referenceIndex,
      kind, expectedStatus, kind & ".md#ERR-" & kind)

  # Token, AST, type, and parser inventories ------------------------------
  for token in TokenKind:
    if "`" & $token & "`" notin coverage:
      fail("coverage.md does not list token " & $token)
  for node in NodeKind:
    if "`" & $node & "`" notin coverage:
      fail("coverage.md does not list AST node " & $node)
  for typ in TypeKind:
    if "`" & $typ & "`" notin coverage:
      fail("coverage.md does not list type kind " & $typ)

  let parserSource = readText("src/parser/parser.nim")
  for production in parserProductions(parserSource):
    if "`" & production & "`" notin coverage:
      fail("coverage.md does not list parser production " & production)

  # Anchors and links ------------------------------------------------------
  let mdFiles = markdownFiles(DocsRoot)
  var anchorsByFile = initTable[string, HashSet[string]]()
  var anchorOwners = initTable[string, seq[string]]()

  for path in mdFiles:
    let content = readText(path)
    let ids = anchorsIn(content)
    var seen = initHashSet[string]()
    for anchor in ids:
      if anchor in seen:
        fail(path & ": duplicate anchor " & anchor)
      seen.incl anchor
      anchorOwners.mgetOrPut(anchor, @[]).add path
    anchorsByFile[path] = seen

    let docId = metadata(content, "doc-id")
    if docId.len > 0 and docId notin seen:
      fail(path & ": doc-id " & docId & " has no matching anchor in the file")

  for anchor, owners in anchorOwners:
    if owners.len > 1:
      fail("anchor " & anchor & " is defined in multiple files: " &
        owners.join(", "))

  var linkCount = 0
  for path in mdFiles:
    let content = readText(path)
    for target in linksIn(content):
      if target.len == 0:
        continue
      if target.startsWith("http://") or target.startsWith("https://") or
          target.startsWith("mailto:") or target.startsWith("ftp://"):
        continue
      inc linkCount

      var filePart = target
      var anchor = ""
      let hash = filePart.find('#')
      if hash >= 0:
        anchor = filePart[hash + 1 .. ^1]
        filePart = filePart[0 ..< hash]

      if filePart.len == 0:
        if anchor.len > 0 and anchor notin anchorsByFile[path]:
          fail(path & ": link " & target & " points to missing same-file anchor")
        continue

      let resolved = normalizedPath(path.parentDir / filePart)
      if not fileExists(resolved):
        fail(path & ": link " & target & " points to missing file " & resolved)
        continue
      if anchor.len > 0 and resolved.endsWith(".md"):
        if resolved notin anchorsByFile:
          let targetContent = readText(resolved)
          anchorsByFile[resolved] = anchorsIn(targetContent).toHashSet()
        if anchor notin anchorsByFile[resolved]:
          fail(path & ": link " & target & " points to missing anchor " &
            anchor & " in " & resolved)

  # Executable snippets ----------------------------------------------------
  var snippets: seq[DocSnippet]
  for path in mdFiles:
    let content = readText(path)
    snippets.add snippetList(content, path)

  for snippet in snippets:
    for expected in snippet.expected:
      if expected notin kindSet:
        fail(snippet.where & ": expect-errors names unknown kind " & expected)
    var actual: seq[string]
    try:
      actual = analyze(snippet.source).mapIt($it)
    except CatchableError as exc:
      fail(snippet.where & ": analysis raised " & $exc.name & ": " & exc.msg)
      continue
    if actual != snippet.expected:
      fail(snippet.where & ": expected [" & snippet.expected.join(", ") &
        "], got [" & actual.join(", ") & "]")

  # Example program --------------------------------------------------------
  let example = readText("examples/rpn.kovy")
  if example.len > 0:
    try:
      let actual = analyze(example).mapIt($it)
      if actual.len > 0:
        fail("examples/rpn.kovy produced errors: " & actual.join(", "))
    except CatchableError as exc:
      fail("examples/rpn.kovy raised " & $exc.name & ": " & exc.msg)

  if failures.len == 0:
    echo "docs check passed: ", mdFiles.len, " Markdown pages, ",
      snippets.len, " executable snippets, ", kinds.len, " error kinds, ",
      linkCount, " internal links"
    quit(0)
  else:
    echo "docs check failed: ", failures.len, " problem(s)"
    quit(1)

main()