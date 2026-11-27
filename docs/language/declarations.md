# Declarations

<!-- doc-id: KOVY-DECLARATIONS -->
<!-- status: current -->

<a id="KOVY-DECLARATIONS"></a>
A declaration introduces one or more names with one declared type. Declarations
may appear at global scope, in function bodies, and in branch/loop blocks.

## Syntax

<a id="SYN-DECL-GROUP"></a>
### Declaration form

```ebnf
declaration = type [ "mut" ] IDENT [ "=" expression ]
              { "," IDENT [ "=" expression ] } ;
```

```kovy
int x
int y = 1
int a = 1, b = 2
bool mut flag = false
```

The type is mandatory. Kovy has no `var`, `let`, `const`, `auto`, or
initializer-based type inference. The initializer is optional. A declaration
without an initializer is allowed; generated Nim uses `var`, so the value is
zero-initialized by the Nim backend even when the Kovy symbol is immutable.

`mut` follows the complete type and precedes the name. This is the only
declaration-level mutability marker.

## Multiple names

<a id="SEM-DECL-GROUP-ORDER"></a>
### Grouped names

Names in one declaration share one type. Each entry may have its own
initializer:

```kovy
int a = 1, b = a + 1, c
```

Initializers are processed in source order. The parser recovers source order
from token line and column even though the AST uses a table. A later name in
the same declaration may refer to an earlier name.

A comma followed by another type is a syntax error in a variable declaration;
to change type, start a new declaration. Function parameters have different
grouping rules; see [functions](functions.md#SYN-FUNC-PARAMS).

## Scope and redeclaration

<a id="SEM-DECL-RULES"></a>
### Declaration rules

- A name may be declared only once in the same scope.
- A declaration in a nested branch, loop, or function body may shadow an outer
  name. Parameters occupy their own scope and may be shadowed by a body-local
  declaration in current sema.
- Global names are visible in function bodies.
- A function name and a non-function name cannot occupy the same global name;
  function-vs-variable collisions use sema redeclaration/redefinition paths.
- A declaration is visible only after its own entry has been visited. In a
  grouped declaration this follows source order.
- The initializer is checked against the declared type with `fits`.
- A `mut` declaration produces a mutable symbol type; an ordinary declaration
  produces the declared type itself.

Duplicate names inside one declaration are caught by the parser with
`errRedeclaration`. Duplicate names across statements are caught by sema with
the same error kind.

## Initialization and generated code

<a id="SEM-DECL-INIT"></a>
### Initialization

- An initialized immutable declaration is emitted as Nim `let`.
- A mutable declaration, or any uninitialized declaration, is emitted as Nim
  `var`.
- Nim `var` initializes its storage; this is why an uninitialized Kovy `int`
  reads as zero in generated programs.
- Kovy sema still treats an uninitialized non-`mut` symbol as immutable: it
  cannot be assigned later.
- A mutable declaration's initializer may be any expression of a fitting type.
- `alloc` and array initializers are expressions and follow their own rules.

## Void declarations

<a id="SEM-DECL-VOID"></a>
### `void` variables

The parser accepts `void x` and sema accepts the declaration because it only
checks initializer fitting. A `void` variable has no usable value and
generated Nim may reject it when the Nim compiler is run. This is a current
implementation gap. Use `void` only as a function return type.

## Examples

<a id="EX-DECL-BASIC"></a>
<!-- expect-errors: OK -->
```kovy
int x = 1
int mut y = x + 1
int a = 1, b = a + 1
bool flag = true
```

<a id="EX-DECL-SHADOW"></a>
<!-- expect-errors: OK -->
```kovy
int x = 1

int f(int value):
  int x = 2
  if true:
    int value = 3
  return x
```

<a id="EX-DECL-REDECL"></a>
<!-- expect-errors: errRedeclaration -->
```kovy
int x = 1
int x = 2
```

## Diagnostics

- [ERR-errRedeclaration](../errors/errRedeclaration.md#ERR-errRedeclaration)
- [ERR-errDoesNotFit](../errors/errDoesNotFit.md#ERR-errDoesNotFit)
- [ERR-errSyntax](../errors/errSyntax.md#ERR-errSyntax)
- [ERR-errUnknownSymbol](../errors/errUnknownSymbol.md#ERR-errUnknownSymbol)
- [ERR-errImmutableAssignment](../errors/errImmutableAssignment.md#ERR-errImmutableAssignment)

## Implementation

- `src/parser/parser.nim`: `parseDecl`, `parseStmt`.
- `src/visitors/sema.nim`: `visit(Decl)`, `symbolExistsInScope`,
  `newSymbol`, `pushScope`, `popScope`.
- `src/visitors/nimgen.nim`: `visit(Decl)`.