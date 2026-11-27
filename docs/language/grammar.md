# Canonical grammar

<!-- doc-id: KOVY-GRAMMAR -->
<!-- status: current -->

<a id="KOVY-GRAMMAR"></a>
This is the canonical syntax summary. It follows `src/parser/parser.nim` and
`src/parser/lexer.nim`; where the parser has a special case, the note below
the production is normative.

## Notation

```text
{ x }      zero or more
[ x ]      optional
x | y      alternative
"x"        literal token
```

`EOS` is a newline-derived or semicolon-derived statement separator. `INDENT`
and `DEDENT` are synthetic indentation tokens. `EOF` ends the file.

## Program

<a id="SYN-GRAMMAR-PROGRAM"></a>
```ebnf
program     = { statement } EOF ;
statement   = declaration
            | functionDecl
            | branch
            | whileStmt
            | "break"
            | "continue"
            | returnStmt
            | expression ;
```

A simple statement must be followed by `EOS`, `EOF`, or a dedent. The parser
has two current exceptions:

- after `branch`, `whileStmt`, or `functionDecl` it does not require an `EOS`
  if the next token is not one;
- a function declaration without `:` is a forward declaration even if the
  next statement starts on the same line.

An unexpected deeper indentation in statement position is `errIndent`; a
missing separator is `errSyntax`. See
[SEM-GRAMMAR-SEPARATORS](#SEM-GRAMMAR-SEPARATORS).

## Types

<a id="SYN-GRAMMAR-TYPES"></a>
```ebnf
type        = baseType { "*" | "(" [ typeArg { "," typeArg } [ "," ] ] ")" } ;
typeArg     = [ "mut" ] type ;
baseType    = "int" | "bool" | "void" ;
```

- `*` is a pointer suffix and may repeat: `int**`.
- `(` after a type starts a function type; it is not grouping.
- A function type has the form `returnType(argType, ...)`.
- `mut` in a type argument wraps the following type: `int(mut int, int)`.
- The suffix loop may mix `*` and function types: `int(bool)*` is a pointer to
  a function; `int*(bool)` is a function returning `int*`.
- A `mut` at declaration level is written after the whole type and before the
  declared name, not before `int`.

## Declarations and functions

<a id="SYN-GRAMMAR-DECLARATIONS"></a>
```ebnf
declaration  = type [ "mut" ] IDENT [ "=" expression ]
               { "," IDENT [ "=" expression ] } ;

functionDecl = type [ "mut" ] IDENT "(" [ parameters ] ")"
               [ ":" block ] ;

parameters   = parameterGroup { "," parameterGroup } [ "," ] ;
parameterGroup = type [ "mut" ] IDENT [ "=" expression ]
                 { "," IDENT [ "=" expression ] } ;
```

The parser distinguishes a function from a variable declaration by the token
after the first identifier: `(` means function declaration. A variable
declaration has no trailing comma; function parameters, call arguments, and
array literals do accept a trailing comma.

Parameters are grouped by a shared type. `int a, b, bool c` means two `int`
parameters and one `bool` parameter. A comma followed by an identifier
continues the current group; a comma followed by a type starts a new group.
Default values are parsed but rejected by sema with
`ERR-errDefaultForbidden`.

A function without `:` has no body and is a forward declaration. A function
with `:` must have a non-empty body (`ERR-errEmptyFunctionBody`).

## Blocks

<a id="SYN-GRAMMAR-BLOCK"></a>
```ebnf
block        = ":" ( INDENT { statement } DEDENT | statement ) ;
```

An inline block is exactly one statement and must end at an `EOS`. An indented
block is a sequence of statements terminated by `DEDENT`; it may be empty for
`if` and `while`, but function bodies are checked separately. An inline
statement followed by an indented continuation is `errIndent`.

## Control statements

<a id="SYN-GRAMMAR-CONTROL"></a>
```ebnf
branch       = "if" expression block
               { "elif" expression block }
               [ "else" block ] ;

whileStmt    = "while" expression block ;

returnStmt   = "return" [ expression ] ;
```

`break` and `continue` take no operands. `return` omits its expression only
when the next token is already `EOS`; at a dedent or EOF, the parser tries to
parse an expression and can report `errExpressionExpected`. A trailing newline
before the dedent supplies the `EOS` in the usual case.

## Expressions

<a id="SYN-GRAMMAR-EXPRESSIONS"></a>
```ebnf
expression  = assignment ;
assignment  = orExpr [ "=" assignment ] ;
orExpr      = andExpr { "or" andExpr } ;
andExpr     = comparison { "and" comparison } ;
comparison  = additive { ( ">" | "<" | ">=" | "<=" | "==" | "!=" ) additive } ;
additive    = multiplicative { ( "+" | "-" ) multiplicative } ;
multiplicative = unary { ( "*" | "/" ) unary } ;
unary       = ( "+" | "-" | "not" | "#" | "addr" ) unary | postfix ;
postfix     = primary { "(" [ expression { "," expression } [ "," ] ] ")" } ;
primary     = NUMBER
            | IDENT
            | "true"
            | "false"
            | "(" expression ")"
            | allocExpr
            | arrayLiteral ;
```

`=` is right-associative. Comparison, `and`, `or`, addition, and
multiplication are left-associative. Unary operators bind tighter than binary
operators. A postfix call binds tighter than a unary operator, so `#p()` means
`#(p())`, not `(#p)()`. Use `(#p)()` to call through a function pointer.

`/` is integer division and is emitted as Nim `div`. There is no `%` operator.

## Allocation and array literals

<a id="SYN-GRAMMAR-ALLOC-ARRAY"></a>
```ebnf
allocExpr   = "alloc" type
            | "alloc" expression "of" type ;

arrayLiteral = "[" [ expression { "," expression } [ "," ] ] "]"
               [ "of" type ] ;
```

`alloc int` is the shorthand for one element: it is parsed as if the count were
the literal `1`. `alloc expression of type` is the general form. Because the
short form triggers when the token after `alloc` is a type keyword, `alloc int
+ 1` is parsed as `(alloc int) + 1`, not as an allocation count expression.

The `of type` suffix on an array literal is optional. Without it, the element
type is inferred from the first element; an empty literal then has no type and
triggers `ERR-errArrayTypeRequired`.

## Statement separators

<a id="SEM-GRAMMAR-SEPARATORS"></a>
### Separator rules

- Newlines and semicolons both produce `EOS`; repeated separators collapse.
- A missing `EOS` between two simple statements is `errSyntax`.
- Unexpected indentation after a statement is `errIndent`.
- A syntactic statement whose parse failed is replaced by an invalid node; the
  parser skips to the next `EOS`/`EOF`/dedent for recovery.
- The parser accepts a trailing comma in call arguments, function parameters,
  and array literals. It does not accept one in a variable declaration group.

## Related pages

- [Lexical structure](lexical.md#KOVY-LEXICAL)
- [Indentation](indentation.md#KOVY-INDENTATION)
- [Precedence table](../reference/precedence.md#REF-PRECEDENCE)
- [Expressions](expressions.md#KOVY-EXPRESSIONS)
- [Statements](statements.md#KOVY-STATEMENTS)