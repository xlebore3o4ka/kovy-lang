# Expressions

<!-- doc-id: KOVY-EXPRESSIONS -->
<!-- status: current -->

<a id="KOVY-EXPRESSIONS"></a>
Expressions produce values of Kovy types. Assignment is itself an expression.
Every expression form is parsed by the productions in
[KOVY-GRAMMAR](grammar.md#SYN-GRAMMAR-EXPRESSIONS).

## Primary expressions

<a id="SYN-EXPR-PRIMARY"></a>
### Primaries

```ebnf
primary = NUMBER | IDENT | "true" | "false" | "(" expression ")"
        | allocExpr | arrayLiteral ;
```

- A number is a decimal integer literal.
- An identifier resolves a visible symbol. A bare global function name has a
  function type; an overloaded name requires an expected function type or a
  call.
- `true` and `false` are boolean literals.
- Parentheses preserve grouping and may surround any expression.
- `alloc` and array literals are described in
  [pointers](pointers.md#SYN-ALLOC) and
  [arrays](arrays.md#SYN-ARRAY-LITERAL).

<a id="SYN-EXPR-LITERAL"></a>
### Literals

Number literals initially have the internal number-literal type; boolean
literals have the bool-literal type. They become `int` or `bool` when the
expected type requires it. Binary arithmetic always produces concrete `int`;
comparisons produce `bool`.

<a id="SYN-EXPR-SYMBOL"></a>
### Symbols

A symbol reference is checked against the innermost visible scope. Unknown
names produce `errUnknownSymbol` with an optional edit-distance suggestion.
Single global function names resolve directly; overloaded global names require
an expected function type. Mutable symbols carry write permission; see
[mutability](mutability.md#KOVY-MUTABILITY).

## Calls

<a id="SYN-EXPR-CALL"></a>
### Calls

```ebnf
postfix = primary { "(" [ expression { "," expression } [ "," ] ] ")" } ;
```

Calls are postfix and may chain: `get()(1)`. A trailing comma is allowed.
Arguments are positional; there are no named arguments or default values.
A call expression is parsed by `parsePostfix`, so a postfix call binds tighter
than unary `#` and `addr`.

```kovy
int add(int a, int b):
  return a + b

int x = add(1, 2)
```

If the callee is an overload set with more than one candidate, overload
resolution runs in `resolveOverloadCall`; see
[overloads](overloads.md#SEM-OVL-RESOLUTION). With one function value, the
generic call path checks arity and each argument with `conversionCost`.

A void call may be used as an expression statement. Generated code emits the
call directly; non-void expression statements are emitted with `discard`.

## Unary operators

<a id="SYN-EXPR-UNARY"></a>
### Unary forms

```ebnf
unary = ( "+" | "-" | "not" | "#" | "addr" ) unary | postfix ;
```

| Form | Operand | Result |
|---|---|---|
| `+x` | number literal or `int` | `int` |
| `-x` | number literal or `int` | `int` |
| `not x` | bool literal or `bool` | `bool` |
| `#x` | pointer after stripping `mut` | pointee type; mutable if the pointer expression grants write |
| `addr x` | mutable expression | pointer to its type; never grants write by itself |

`#` is dereference, not a comment introducer. `addr` requires a mutable lvalue
or a mutable-returning call. `alloc` and array literals are not considered
writable by themselves; bind them to a mutable pointer symbol before writing.

The postfix call binding is important. These two forms parse differently:

```kovy
#p()
(#p)()
```

The first is `#(p())`: call `p`, then dereference the result. The second is
`(#p)()`: dereference `p`, then call the resulting function value.

## Binary operators

<a id="SYN-EXPR-BINARY"></a>
### Binary forms

```ebnf
assignment     = orExpr [ "=" assignment ] ;
orExpr         = andExpr { "or" andExpr } ;
andExpr        = comparison { "and" comparison } ;
comparison     = additive { ( ">" | "<" | ">=" | "<=" | "==" | "!=" ) additive } ;
additive       = multiplicative { ( "+" | "-" ) multiplicative } ;
multiplicative = unary { ( "*" | "/" ) unary } ;
```

Precedence is documented in
[REF-PRECEDENCE](../reference/precedence.md#REF-PRECEDENCE).

- `+`, `-`, `*`, `/` operate on `int`/number literals.
- `<`, `>`, `<=`, `>=` operate on `int`/number literals and produce `bool`.
- `==` and `!=` operate on two integer-like operands or two boolean-like
  operands and produce `bool`.
- `and` and `or` operate on boolean-like operands and produce `bool`.
- Pointer arithmetic is described in
  [pointers](pointers.md#SEM-PTR-ARITHMETIC).
- `/` is integer division; the generated Nim operator is `div`.
- There is no `%`, `&&`, `||`, bitwise operator, or exponentiation.

`and` and `or` are emitted as Nim `and`/`or`, so generated code short-circuits.
Kovy sema visits and type-checks both operands.

## Assignment

<a id="SYN-EXPR-ASSIGN"></a>
### Assignment expressions

Assignment is right-associative:

```kovy
a = b = 1
```

The left side must be a mutable expression. The right side is checked with
`fits` against the inner type of the left side. The expression result is a
mutable value of that inner type and carries the left side's write permission.
A successful simple assignment is generated as `(lhs = rhs; lhs)`.

Assignment through a call expression uses a temporary address so the call is
evaluated once:

```kovy
#pick() = 5
```

This is emitted as a block that takes the address of the call result, writes
through it, and yields the written value.

Assignment is not a statement-only construct. It can appear inside a
condition or another expression, subject to the resulting type.

## Parentheses and evaluation

<a id="SEM-EXPR-EVAL"></a>
### Evaluation

The compiler preserves source-level grouping with parentheses in generated
Nim. It does not introduce a separate Kovy evaluation-order guarantee:
runtime order follows the emitted Nim expression. The sema pass visits the
left operand before the right operand; that is a compile-time check order, not
a promise about side effects.

`and`/`or` short-circuit because they are emitted as Nim `and`/`or`.

## Expression statements

<a id="SEM-EXPR-STATEMENT"></a>
### Expression statements

Any expression may be a statement. An expression statement is accepted after
parsing; sema visits the expression and records errors. Generated code emits
a void call directly and prefixes other expression values with `discard`.

## Current quirks

<a id="SEM-EXPR-QUIRKS"></a>
- `!` is lexed but is not an expression; use `not`.
- A bare overloaded function name is an error unless the expected type is a
  function type or it is the callee of a call.
- `alloc int + 1` is parsed as `(alloc int) + 1`, because `int` triggers the
  short allocation form.
- Assignment to a non-mutable expression reports `errImmutableAssignment`,
  even when the left side is syntactically not a storage location.
- A mutable assignment expression can be used where a mutable value is
  expected; this is how chained assignment obtains its type.

## Diagnostics

- [ERR-errUnknownSymbol](../errors/errUnknownSymbol.md#ERR-errUnknownSymbol)
- [ERR-errDoesNotFit](../errors/errDoesNotFit.md#ERR-errDoesNotFit)
- [ERR-errBinaryMismatch](../errors/errBinaryMismatch.md#ERR-errBinaryMismatch)
- [ERR-errUnaryMismatch](../errors/errUnaryMismatch.md#ERR-errUnaryMismatch)
- [ERR-errImmutableAssignment](../errors/errImmutableAssignment.md#ERR-errImmutableAssignment)
- [ERR-errNotCallable](../errors/errNotCallable.md#ERR-errNotCallable)
- [ERR-errWrongArity](../errors/errWrongArity.md#ERR-errWrongArity)
- [ERR-errArgMismatch](../errors/errArgMismatch.md#ERR-errArgMismatch)
- [ERR-errAmbiguousFunctionReference](../errors/errAmbiguousFunctionReference.md#ERR-errAmbiguousFunctionReference)
- [ERR-errDerefNonPointer](../errors/errDerefNonPointer.md#ERR-errDerefNonPointer)
- [ERR-errAddrFromImmutable](../errors/errAddrFromImmutable.md#ERR-errAddrFromImmutable)

## Tests

- `tests/tSema.nim`: array inference, unknown-symbol suggestions
- `tests/tFunc.nim`: calls, function values, overloads
- `tests/tPtr.nim`: dereference, addr, pointer arithmetic, function pointers