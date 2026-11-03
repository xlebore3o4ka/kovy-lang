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

proc skipWhitespaces*(self: Lexer) =
  while self.peek() in {' ', '\t', '\r', '\n'}:
    self.advance()

proc consume*(self: Lexer) =
  self.advance()

proc nextTok*(self: Lexer): Token =
  if self.hasPeekedToken:
    result = self.peekedToken
    self.hasPeekedToken = false
    return

  self.skipWhitespaces()

  let line = self.line
  let col = self.col

  let c = self.peek()

  if c in {'0'..'9'}:
    var buffer: string

    while (let c = self.peek(); c) in {'0'..'9'}:
      self.consume()
      buffer &= c

    return newToken(tkNumber, buffer, line, col, self.file)

  elif $c in operatorsTable:
    self.advance()
    var op = $c
    if op & self.peek() in operatorsTable:
      op &= self.peek()
      self.advance()

    return newToken(operatorsTable[op], op, line, col, self.file)

  self.errors.add newError(errUnknownCharacter, self.file, line, col, 1, c)

proc peekTok*(self: Lexer): Token =
  self.peekedToken = self.nextTok()
  self.hasPeekedToken = true
  self.peekedToken
