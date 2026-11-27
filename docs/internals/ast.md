# AST internals

<!-- doc-id: INT-AST -->
<!-- status: current -->

<a id="INT-AST"></a>
The AST is declared in `src/ast.nim`. Every node has a `NodeKind`, a `Token`,
and, for expressions, a semantic `grantsWrite` flag.

## Node hierarchy

<a id="INT-AST-NODEKINDS"></a>
### Node kinds

| `NodeKind` | Concrete type | Base | Fields |
|---|---|---|---|
| `nkInvalid` | `InvalidExpr`, `InvalidStmt` | `Expr`, `Stmt` | token only |
| `nkNumber` | `Number` | `Expr` | `value: int` |
| `nkBool` | `Bool` | `Expr` | `value: bool` |
| `nkBinary` | `Binary` | `Expr` | `lvalue`, `rvalue` |
| `nkUnary` | `Unary` | `Expr` | `value` |
| `nkBlock` | `Block` | `Stmt` | `stmts: seq[Stmt]` |
| `nkSymbol` | `Symbol` | `Expr` | `resolvedOverloadId: int` |
| `nkExprStmt` | `ExprStmt` | `Stmt` | `expr: Expr` |
| `nkDecl` | `Decl` | `Stmt` | `typ`, `mut`, `decls` |
| `nkBranch` | `Branch` | `Stmt` | `cond`, `ifThen`, `elifs`, `elseThen` |
| `nkWhile` | `While` | `Stmt` | `cond`, `body` |
| `nkBreak` | `Break` | `Stmt` | token only |
| `nkContinue` | `Continue` | `Stmt` | token only |
| `nkFuncDecl` | `FuncDecl` | `Stmt` | `returnType`, `mut`, `arguments`, `body`, `overloadId` |
| `nkReturn` | `Return` | `Stmt` | `value: Expr` (may be nil) |
| `nkCall` | `Call` | `Expr` | `value`, `arguments`, `resolvedOverloadId`, `isVoidCall` |
| `nkAlloc` | `Alloc` | `Expr` | `count`, `elemType` |
| `nkArrayLit` | `ArrayLit` | `Expr` | `elements`, `hasElemType`, `elemType` |

`Expr` adds `grantsWrite*: bool`, a sema result used for pointer write
permission. `Stmt` adds no fields.

## Declarations

<a id="INT-AST-DECL"></a>
### `Decl`

A `Decl` stores one declared type and a table from name to
`(token, value)`. The table does not preserve insertion order. `declEntries`
recovers source order by sorting on line, then column, then name.

Consequences:

- Duplicate names cannot be represented: a later entry with the same key
  overwrites the earlier one if the parser did not already reject it.
- Equal line and column entries are ordered by name. This only matters for
  synthetic or malformed declarations.
- A missing initializer is represented by `value == nil`.

Function parameters are represented as a `seq[Decl]`, one `Decl` per parameter
name. This lets each parameter have its own token and default value.
`FuncDecl.body == nil` means a forward declaration; a non-nil body is a
`Block`.

## Expression flags

<a id="INT-AST-SEMA-FIELDS"></a>
### Sema-populated fields

| Field | Set by | Meaning |
|---|---|---|
| `Expr.grantsWrite` | sema | expression may be written through |
| `Symbol.resolvedOverloadId` | sema | selected global overload, 0 for ordinary or unresolved |
| `Call.resolvedOverloadId` | sema | selected global overload, 0 otherwise |
| `Call.isVoidCall` | sema | callee returns `void` |
| `FuncDecl.overloadId` | sema | generated global function id, 0 for nested |
| `ArrayLit.elemType` | parser or sema | explicit or inferred element type |
| `Alloc.elemType` | parser | allocation element type |

The parser initially leaves `grantsWrite`, `resolvedOverloadId`, and
`isVoidCall` at their default `false`/`0` values.

## Invalid nodes

<a id="INT-AST-INVALID"></a>
### Invalid nodes

The parser constructs `InvalidExpr` and `InvalidStmt` for recovery. They keep
the offending token. Their `toStr` is empty. Sema treats an invalid statement
as successful and does not add a new diagnostic; the parser has already
reported the problem. Invalid expressions generally produce `typeError` when
visited.

## String forms

<a id="INT-AST-TOSTR"></a>
### `toStr`

`Expr.toStr` is used in diagnostics and overload listings:

- numbers and booleans use their values;
- binary expressions parenthesize nested binary operands;
- unary expressions parenthesize a binary operand; `not` and `addr` put a
  space after the keyword, other unary operators do not;
- calls print `callee(arg, ...)`;
- `alloc` prints `alloc <count> of <type>`;
- array literals print `[a, b]` with ` of T` only when explicitly written.

`Stmt.toStr` prints blocks as `{stmt; stmt}`, declarations as
`type name = value, ...`, and function declarations as
`type name(args) body`. A forward declaration has no body. These strings are
diagnostic aids, not canonical source.

The parser loses the distinction between `alloc int` and `alloc 1 of int` in
`toStr`; both contain the synthetic count `1` and print as `alloc 1 of int`.

## Source order

<a id="INT-AST-ORDER"></a>
### Source order

`Block.stmts` is ordered. `Branch.elifs` is ordered. `Decl.decls` is not
ordered; use `declEntries`. This is why sema visits declaration entries through
`declEntries` and why diagnostics can still report a later entry first only if
the caller ignores source order.

## Implementation

- `src/ast.nim`: all node types and constructors
- `src/parser/parser.nim`: node construction
- `src/visitors/sema.nim`: annotation fields
- `src/visitors/nimgen.nim`: consumers of the annotations