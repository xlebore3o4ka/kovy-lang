import tokens
import ../errors
import std/[tables]

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
      self.atLineStart = false
      return false

  var spaces = 0
  while self.peek() == ' ' or self.peek() == '\t':
    if self.indentType == '\0':
      self.indentType = self.peek()
      self.indentStack.add(0)
    elif self.peek() != self.indentType:
      self.errors.add newError(errUnknownCharacter, self.file, self.line, self.col, 1, self.peek())
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
    return newToken(tkEOS, ";", self.line, self.col, self.file)

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
  elif c in {'0'..'9'}:
    var buffer = ""
    while self.peek() in {'0'..'9'}:
      buffer &= self.peek()
      self.advance()
    result = newToken(tkNumber, buffer, line, col, self.file)
  else:
    if $c in operatorsTable:
      self.advance()
      var op = $c
      if op & $self.peek() in operatorsTable:
        op &= $self.peek()
        self.advance()
      result = newToken(operatorsTable[op], op, line, col, self.file)
    else:
      self.errors.add newError(errUnknownCharacter, self.file, line, col, 1, c)

proc newLexer*(source: string, errors: ErrorContext): Lexer =
  result = Lexer(source: source, errors: errors)

proc peekTok*(self: Lexer): Token =
  self.peekedToken = self.nextTok()
  self.hasPeekedToken = true
  self.peekedToken