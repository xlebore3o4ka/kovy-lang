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

proc handleIndentDedent(self: Lexer; spaces: Natural): bool =
  if self.indentType == '\0':
    self.indentType = ' '
    self.indentStack.add(0)

  if spaces > self.indentStack[^1]:
    self.indentStack.add(spaces)
    self.peekedToken = newToken(tkIndent, "", self.line, self.col, self.file)
    return true
  elif spaces < self.indentStack[^1]:
    while self.indentStack[^1] > spaces and self.indentStack.len > 1:
      discard self.indentStack.pop()
      self.peekedToken = newToken(tkDedent, "", self.line, self.col, self.file)
      return true
    if spaces != self.indentStack[^1]:
      self.errors.add newError(errUnknownCharacter, self.file, self.line, self.col, 1, ' ')
  return false

proc handleIndentation(self: Lexer): bool =
  while true:
    case self.peek()
    of ' ', '\t':
      break
    of '\n', '\r':
      self.pendingEos = false
      self.advance()
      continue
    of '\0':
      if self.emitDedentsIfNeeded():
        self.hasPeekedToken = true
        self.atLineStart = false
        return true
      self.atLineStart = false
      return false
    else:
      # Токен на колонке 0 (например `elif`/`else`): сбросить отступ до уровня 0.
      self.atLineStart = false
      if self.handleIndentDedent(0):
        self.pendingEos = false
        self.hasPeekedToken = true
        return true
      return false

  var spaces = 0
  while self.peek() == ' ' or self.peek() == '\t':
    if self.indentType == '\0':
      self.indentType = self.peek()
      self.indentStack.add(0)
    elif self.peek() != self.indentType:
      self.errors.add newError(errIndent, self.file, self.line, self.col, 1, self.peek())
      break
    spaces += 1
    self.advance()

  self.atLineStart = false
  if self.handleIndentDedent(spaces):
    self.pendingEos = false
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

  self.skipHorizontalWhitespaces()

  if self.pendingEos:
    self.pendingEos = false
    result = newToken(tkEOS, ";", self.line, self.col, self.file)
  else:
    let line = self.line
    let col = self.col
    let c = self.peek()

    if c == '\n':
      self.advance()
      self.atLineStart = true
      self.pendingEos = true
      if self.handleIndentation():
        result = self.peekedToken
        self.hasPeekedToken = false
      elif self.pendingEos:
        self.pendingEos = false
        result = newToken(tkEOS, ";", self.line, self.col, self.file)

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

proc newLexer*(source: string, errors: ErrorContext): Lexer =
  result = Lexer(source: source, errors: errors)

proc peekTok*(self: Lexer): Token =
  self.peekedToken = self.nextTok()
  self.hasPeekedToken = true
  self.peekedToken