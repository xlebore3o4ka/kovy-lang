import tokens
import ../errors
import std/[tables, strutils]

type
  Lexer* = ref object
    source*: string
    pos*: Natural
    col*: Positive = 1
    line*: Positive = 1
    file*: Natural
    errors*: ErrorContext

    hasPeekedToken*: bool
    peekedToken*: Token

    atLineStart*: bool
    pendingEos*: bool
    lastWasEos*: bool
    indentStack*: seq[Natural] = @[]
    indentType*: char = '\0'
    pendingDedents*: int

    eosLine*: Positive = 1
    eosCol*: Positive = 1

proc peek*(self: Lexer): char =
  if self.pos < self.source.len:
    self.source[self.pos]
  else:
    '\0'

proc advance*(self: Lexer) =
  if self.peek() == '\n':
    self.line += 1
    self.col = 1
  elif self.peek() != '\0':
    self.col += 1
  self.pos += 1

proc skipHorizontalWhitespaces*(self: Lexer) =
  while self.peek() in {' ', '\t', '\r'}:
    self.advance()

proc emitDedentsIfNeeded(self: Lexer): bool =
  while self.indentStack.len > 1:
    discard self.indentStack.pop()
    self.peekedToken = newToken(tkDedent, "", self.line, self.col, self.file)
    return true
  return false

proc handleIndentDedent(self: Lexer; spaces: Natural, indentText = ""): bool =
  if self.indentType == '\0':
    self.indentType = ' '
    self.indentStack.add(0)

  if spaces > self.indentStack[^1]:
    self.indentStack.add(spaces)
    self.pendingEos = false
    let indentCol = max(1, self.col - indentText.len)
    self.peekedToken = newToken(tkIndent, indentText, self.line, indentCol, self.file)
    return true
  elif spaces < self.indentStack[^1]:
    while self.indentStack.len > 1 and self.indentStack[^1] > spaces:
      discard self.indentStack.pop()
      self.pendingDedents += 1
    if spaces != self.indentStack[^1]:
      self.errors.add newError(errUnknownCharacter, self.file, self.line, self.col, 1, ' ')
  return false

proc handleIndentation(self: Lexer): bool =
  while true:
    case self.peek()
    of ' ', '\t':
      break
    of '\n', '\r':
      self.advance()
      continue
    of '\0':
      if self.indentStack.len > 1:
        self.pendingDedents += self.indentStack.len - 1
        self.indentStack.setLen(1)
      self.atLineStart = false
      return false
    else:
      self.atLineStart = false
      if self.handleIndentDedent(0):
        self.hasPeekedToken = true
        return true
      return false

  var spaces = 0
  var indentText = ""
  while self.peek() == ' ' or self.peek() == '\t':
    indentText.add self.peek()
    if self.indentType == '\0':
      self.indentType = self.peek()
      self.indentStack.add(0)
    elif self.peek() != self.indentType:
      self.errors.add newError(errIndent, self.file, self.line, self.col, 1, self.peek())
      break
    spaces += 1
    self.advance()

  self.atLineStart = false
  # A whitespace-only blank line must be ignored, like an empty line, instead of
  # being treated as a new indentation level. Its trailing newline keeps any pending
  # EOS from the previous content line.
  if self.peek() in {'\n', '\r', '\0'}:
    while self.peek() in {'\n', '\r'}:
      self.advance()
    return self.handleIndentation()
  if self.handleIndentDedent(spaces, indentText):
    self.hasPeekedToken = true
    return true
  return false

proc nextTok*(self: Lexer): Token =
  if self.hasPeekedToken:
    result = self.peekedToken
    self.hasPeekedToken = false
    return

  if self.atLineStart:
    if self.handleIndentation():
      result = self.peekedToken
      self.hasPeekedToken = false
      return
    self.atLineStart = false

  if self.pendingEos:
    self.pendingEos = false
    result = newToken(tkEOS, ";", self.eosLine, self.eosCol, self.file)
    if self.lastWasEos:
      result = self.nextTok()
    else:
      self.lastWasEos = true
    return

  if self.pendingDedents > 0:
    self.pendingDedents -= 1
    result = newToken(tkDedent, "", self.line, self.col, self.file)
    self.lastWasEos = false
    return

  self.skipHorizontalWhitespaces()

  block:
    let line = self.line
    let col = self.col
    let c = self.peek()

    if c == '\n':
      self.eosLine = self.line
      self.eosCol = self.col
      self.advance()
      self.atLineStart = true
      self.pendingEos = true
      result = self.nextTok()
      return

    elif c == '\0':
      if self.emitDedentsIfNeeded():
        result = self.peekedToken
        self.hasPeekedToken = false
      else:
        result = newToken(tkEOF, "", line, col, self.file)

    elif c.isDigit():
      var buffer = ""
      while self.peek().isDigit():
        buffer &= self.peek()
        self.advance()
      result = newToken(tkNumber, buffer, line, col, self.file)

    elif c.isAlphaAscii() or c == '_':
      var buffer = ""
      while (let c = self.peek(); c).isAlphaNumeric() or c == '_':
        buffer &= self.peek()
        self.advance()

      if buffer in keywordsTable:
        result = newToken(keywordsTable[buffer], buffer, line, col, self.file)
      else:
        result = newToken(tkIdent, buffer, line, col, self.file)

    elif $c in operatorsTable:
      self.advance()
      var op = $c
      if op & $self.peek() in operatorsTable:
        op &= $self.peek()
        self.advance()
      if op == ";":
        while self.peek() == ';':
          self.advance()
      result = newToken(operatorsTable[op], op, line, col, self.file)

    else:
      self.advance()
      self.errors.add newError(errUnknownCharacter, self.file, line, col, 1, c)
      result = newToken(tkInvalid, $c, line, col, self.file)

  if result.kind == tkEOS:
    if self.lastWasEos:
      result = self.nextTok()
    else:
      self.lastWasEos = true
  else:
    self.lastWasEos = false

proc newLexer*(source: string, errors: ErrorContext, file: Natural): Lexer =
  result = Lexer(source: source, errors: errors, file: file)

proc peekTok*(self: Lexer): Token =
  self.peekedToken = self.nextTok()
  self.hasPeekedToken = true
  self.peekedToken