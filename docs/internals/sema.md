# Semantic analysis internals

<!-- doc-id: INT-SEMA -->
<!-- status: current -->

<a id="INT-SEMA"></a>
`src/visitors/sema.nim` resolves names, checks types and contexts, assigns
overloads, and annotates the AST. It adds diagnostics to the shared context and
never raises for ordinary source errors.

## State

<a id="INT-SEMA-STATE"></a>
### State

| Field | Purpose |
|---|---|
| `errors` | shared `ErrorContext` |
| `files` | file tracker used in overload and lifetime messages |
| `currentScope` | current lexical scope |
| `symbolScopeStack` | per-name stack of scopes containing that name |
| `contextScopeStack` | branch/loop/function contexts |
| `overloadTable` | global overloads by name |
| `forwardOrder` | forwards in declaration order for `finalize` |
| `nextOverloadId` | generated global function id counter, starts at 1 |

A `Sym` stores its token, `symbolType`, and `scopeDepth`. A `Scope` stores a
depth, a symbol table, and either a parent or the global flag.

## Scope operations

<a id="INT-SEMA-SCOPES"></a>
### Scope operations

- `newSymbol` writes the current scope's table and pushes the scope onto
  `symbolScopeStack[name]`.
- `pushScope` creates a non-global child with depth `parent.depth + 1`, pushes
  it onto the context stack.
- `popScope` pops one entry from `symbolScopeStack` for every name in the
  scope, restores the parent, and pops the context.
- `symbolExists` is true when the per-name stack is non-empty.
- `getSymbol` reads the innermost scope in that stack.
- `symbolExistsInScope` checks only `currentScope.symbolTable`.

A name may therefore have several live scopes. Lookup always uses the last
entry of `symbolScopeStack[name]`.

## Declaration visiting

<a id="INT-SEMA-DECL"></a>
### Declarations

`visit(Decl)`:

1. Computes `symbolType` as `mut T` for a mutable declaration, otherwise `T`.
2. Iterates `declEntries` in source order.
3. Visits each initializer with the declared type as expected type.
4. Checks `fits(actual, declared)`.
5. Checks the name against the current scope only.
6. Inserts the symbol even after an initializer or duplicate error.
7. Returns whether all entries succeeded.

Defaults in parameter declarations use the same `Decl` path.

Duplicate checks use the earlier symbol's token for the "last declared"
addinfo. The new symbol replaces the old table entry in a duplicate situation,
but the scope stack still receives another push for the name; pop removes only
the new one, leaving the old entry.

## Expression visiting

<a id="INT-SEMA-EXPR"></a>
### Expressions

| Node | Result |
|---|---|
| `Number` | `typeNumberLit` |
| `Bool` | `typeBoolLit` |
| `Symbol` | overload signature, function type, or stored symbol type; sets `grantsWrite` from `typeMutable` |
| `Binary(=)` | left must be mutable; right visited with expected inner type; result `mut inner` and left's `grantsWrite` |
| `Binary` | arithmetic/compare/boolean table, or pointer arithmetic |
| `Unary(#)` | pointer check after stripping mutable; result pointee; mutable when operand `grantsWrite` |
| `Unary(addr)` | operand must be mutable; result pointer to inner type; `grantsWrite` stays false |
| `Unary(+/-/not)` | unary table |
| `Call` | overload call or generic call |
| `Alloc` | pointer to element type |
| `ArrayLit` | pointer to inferred/explicit element type |

`Node.grantsWrite` is reset to false at the start of binary, unary, alloc, and
array-literal visits. It is not a general memory-ownership flag.

<a id="INT-SEMA-SYMBOLS"></a>
### Symbol resolution

A symbol first checks `symbolExists`. If absent, it emits
`errUnknownSymbol` with an optional suggestion and returns `typeError`.

If the innermost symbol is global and has function type, `getGlobalOverloads`
returns the overload table entry. One overload resolves directly and sets
`resolvedOverloadId`; more than one emits
`errAmbiguousFunctionReference`. A non-overloaded symbol returns its stored
type.

`visitExpected` is used for initializers, array elements, return values, and
call arguments. If the node is a symbol and the expected type (after stripping
mutable) is a function type, it searches global overloads for an exact
`sameType` match. A miss falls back to ordinary `visit`, which can emit the
ambiguous-reference error.

<a id="INT-SEMA-BINARY"></a>
### Binary checks

Assignment:

- left type must be `typeMutable`;
- right is visited with expected inner type;
- `fits` failure is reported as `errBinaryMismatch`, not `errDoesNotFit`;
- result type is `mut inner`;
- result `grantsWrite` is the left side's flag.

Pointer operands:

- `ptr + int`, `int + ptr`, and `ptr - int` return the pointer type and inherit
  the pointer operand's `grantsWrite`;
- `ptr - ptr` returns `int` when both pointer base types are identical;
- every other pointer combination emits `errBinaryMismatch`.

Scalar operands use `binResult`, which strips mutable wrappers and looks up the
pair in `binOpResult`. Unknown pairs emit `errBinaryMismatch`.

<a id="INT-SEMA-UNARY"></a>
### Unary checks

`#` and `addr` have dedicated checks. Other unary operators strip a mutable
wrapper before looking up `unOpResult`; an unknown pair emits
`errUnaryMismatch`. A `typeError` operand is propagated without another error.

<a id="INT-SEMA-CALLS"></a>
### Calls

If the callee is a symbol with more than one global overload,
`resolveOverloadCall` runs:

1. Visit all arguments without expected types.
2. Reject arity mismatches.
3. Sum `conversionCost` for each argument.
4. Keep minimum-cost candidates.
5. One candidate resolves; several emit `errAmbiguousCall`; none emit
   `errNoMatchingOverload`.
6. The diagnostic argument list uses `diagnosticTypeStr` for actual types and
   `overloadList` for candidates or all overloads.

Otherwise the generic path visits the callee, strips a mutable wrapper, checks
that the base is `typeFunc`, checks arity, and visits each argument with the
parameter type as expected. The first argument that does not convert emits
`errArgMismatch` and aborts the call check. `isVoidCall` and `grantsWrite` are
set from the return type.

The overload path visits arguments without expected types, so an overloaded
function argument that is itself a bare overloaded name can be ambiguous
rather than selected by a parameter type.

## Allocation and arrays

<a id="INT-SEMA-MEMORY"></a>
### Allocation and arrays

`visit(Alloc)`:

1. Sets `grantsWrite = false`.
2. If in a loop context, emits `errAllocInLoop` and remembers failure.
3. Visits the count and propagates an error type.
4. An error element type returns immediately.
5. `void` element type emits `errAllocVoid`.
6. A count that does not fit `int` emits `errAllocCount`.
7. If in a loop, returns `typeError`; otherwise returns `ptr elemType`.

`visit(ArrayLit)`:

1. Sets `grantsWrite = false`.
2. If in a loop context, emits `errAllocInLoop` and sets `failed`.
3. Explicit element type: propagate an error type, reject `void`.
4. No explicit type and no elements: `errArrayTypeRequired`.
5. No explicit type and elements: infer from first; strip mutable; convert a
   literal type to `int`/`bool`; reject inferred `void`.
6. Check remaining elements with `fits`; each failure emits
   `errDoesNotFit` and sets `failed`.
7. Return `typeError` if failed, otherwise `ptr elemType`.

## Statements and control flow

<a id="INT-SEMA-STATEMENTS"></a>
### Statements

- `Block` visits every statement, detects unreachable followers, and always
  returns true.
- `ExprStmt` discards `typeError` and returns true.
- `Branch` checks each condition and visits each body in a fresh branch scope.
- `While` checks the condition and visits the body in a loop scope.
- `Break`/`Continue` require a loop context.
- `Return` requires a function context and applies return rules.
- `FuncDecl` handles parameters, global vs nested declarations, forwards,
  overloads, body scopes, and the all-paths-return check.
- A `typeError` from a condition is still checked by `fits`, which treats it as
  compatible.

## Functions and overloads

<a id="INT-SEMA-FUNCTIONS"></a>
### Functions and overloads

`visit(FuncDecl)` first processes parameter defaults. Each default emits
`errDefaultForbidden` and is cleared from the AST. Parameter types, including
`mut`, form the function type.

- A bodyless function outside global scope emits
  `errForwardOutsideGlobal`.
- A global function name colliding with a non-function is
  `errRedeclaration`; only a function/function collision reaches the
  function-specific checks.
- `findOverload` uses `sameParams`, which compares parameter types only.
- A duplicate bodyless declaration with the same return type is
  `errFuncRedefinition`; different return type is
  `errOverloadByReturnType`.
- A bodyless declaration creates an `Overload` with a new id and adds it to
  `forwardOrder`.
- A definition matching an undefined overload fills it. A return-type or
  parameter-name mismatch is `errFuncSignatureMismatch` and marks the overload
  defined so `finalize` does not also report it.
- A duplicate definition is `errFuncRedefinition` or
  `errOverloadByReturnType` by return type.
- A nested function cannot shadow a visible name and cannot be overloaded. A
  function-name collision and a duplicate nested function both use
  `errFuncRedefinition`; a collision with a variable or parameter uses
  `errRedeclaration`.

Parameters are visited in a `func-arguments` scope. The body is visited in a
`func` scope. After popping, non-void functions run `controlAllReturnPaths`.

`finalize` reports each still-undefined forward as `errUnresolvedForward`.

## Error suppression

<a id="INT-SEMA-RECOVERY"></a>
### Error suppression

`handleErrorType` returns immediately from an expression visit; `manageErrorType`
returns false from a statement visit. Declaration failures do not stop later
entries. Call checks stop after the first argument mismatch. Array literal
checks continue after element mismatches to report each one. Function argument
default errors stop body analysis because `visit(FuncDecl)` returns false
before pushing the body scope.

## Implementation

- `src/visitors/sema.nim`: all semantic logic
- `tests/tSema.nim`, `tests/tFunc.nim`, `tests/tPtr.nim`: executable checks
- Language rules: [KOVY-SCOPES](../language/scopes.md#KOVY-SCOPES),
  [KOVY-CONTROL-FLOW](../language/control-flow.md#KOVY-CONTROL-FLOW)