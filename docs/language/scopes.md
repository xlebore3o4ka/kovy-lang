# Scopes and visibility

<!-- doc-id: KOVY-SCOPES -->
<!-- status: current -->

<a id="KOVY-SCOPES"></a>
Kovy uses lexical scopes. A name resolves to the innermost visible declaration.
There is no module scope, import, namespace, or explicit block statement.

## Scope kinds

<a id="SEM-SCOPE-KINDS"></a>
### Scope kinds

| Scope | Created by | Depth | Notes |
|---|---|---|---|
| global scope | the program | 0 | functions and global variables |
| branch scope | each `if`, `elif`, and `else` body | parent + 1 | one scope per body |
| loop scope | a `while` body | parent + 1 | also establishes loop context |
| function-argument scope | a function declaration's parameters | parent + 1 | parameter names and defaults |
| function-body scope | a function body | argument scope + 1 | local declarations |
| nested function argument/body scopes | nested function declaration | as above | independent function context |

The branch scope is pushed even for an absent `else`; it simply contains no
declarations.

## Visibility order

<a id="SEM-SCOPE-VISIBILITY"></a>
### Visibility order

- A declaration becomes visible after its own entry has been visited.
- Entries of one declaration group are visited in source order, even though
  they are stored in a table. A later entry may refer to an earlier entry.
- An initializer cannot refer to a name declared later in the same group.
- A function name is visible inside its own body, which permits direct
  recursion.
- Global names are visible inside functions.
- A function declared later is not visible to an earlier global statement
  unless a forward declaration was already seen.

```kovy
int a = 1, b = a + 1
int mut c = b
```

An unknown name produces `ERR-errUnknownSymbol`. The diagnostic may include a
suggestion chosen by edit distance from all currently recorded names; see
[TRG-errUnknownSymbol-suggestion](../errors/errUnknownSymbol.md#TRG-errUnknownSymbol-suggestion).

## Shadowing

<a id="SEM-SCOPE-SHADOWING"></a>
### Shadowing

A declaration is rejected only when the same name already exists in the
*current* scope. Declarations in nested branch, loop, and function scopes may
shadow outer names.

| Inner declaration | Outer declaration | Result |
|---|---|---|
| branch local | global/function local | allowed |
| loop local | global/function local | allowed |
| function body local | parameter | allowed in current sema |
| function body local | outer function local | allowed |
| parameter | anything visible outside | parameter shadows it in the function |
| parameter duplicate | another parameter | `errRedeclaration` |
| two locals in one scope | each other | `errRedeclaration` |
| nested function | visible function | `errFuncRedefinition` |
| nested function | visible variable or parameter | `errRedeclaration` |

```kovy
int value = 1

int f(int value):
  int value = 2
  if true:
    bool value = true
  return value
```

The function body declaration shadows the parameter; the branch declaration
shadows both. This is current behaviour, not an error.

## Function names

<a id="SEM-SCOPE-FUNCTIONS"></a>
### Function names and overload sets

Global functions are stored both as a normal symbol and in the global overload
table. A global function name has a function type. When more than one global
overload exists, the bare name requires an expected function type; a call
resolves the overload set instead.

A variable can shadow a global function name in a nested scope. Overload lookup
intentionally requires the innermost symbol to be a global function, so a local
variable with the same name wins.

A nested function may not reuse any name visible at its declaration point. That
check is stricter than ordinary variable shadowing: a collision with a visible
function uses `ERR-errFuncRedefinition`, while a collision with a variable or
parameter uses `ERR-errRedeclaration`.

## Leaving a scope

<a id="SEM-SCOPE-LIFETIME"></a>
### Leaving a scope

Popping a branch, loop, function-body, or argument scope removes its symbols
from visibility. It does not invalidate generated storage immediately: storage
belongs to the generated Nim stack frame, and the current compiler does not
perform a full lifetime analysis. Scope depth is used only by the narrow
mutable-return check in
[SEM-FLOW-RETURN-DANGLING](control-flow.md#SEM-FLOW-RETURN-DANGLING).

Do not rely on a branch-local pointer remaining valid after the branch exits.
The compiler currently accepts many such programs; see
[SEM-PTR-LIFETIME](pointers.md#SEM-PTR-LIFETIME).

## Context scopes

<a id="SEM-SCOPE-CONTEXT"></a>
### Context scopes

Context scopes are a separate stack from lexical symbol scopes. They record
whether execution is inside a branch, loop, function arguments, or function
body.

- `break` and `continue` search outward for a loop context and stop at the
  nearest function boundary.
- `alloc` and array literals search for a loop context and also stop at a
  function boundary.
- `return` searches for any function context. The innermost function context
  supplies the expected return type.
- A function declared inside a loop creates a new function context; its body
  is not inside the surrounding loop for these checks.

See [SEM-FLOW-CONTEXT](control-flow.md#SEM-FLOW-CONTEXT) and
[SYN-STMT-BREAK](statements.md#SYN-STMT-BREAK).

## Current quirks

<a id="SEM-SCOPE-QUIRKS"></a>
- Parameters and body locals are separate scopes, so a body local may shadow a
  parameter with the same type and name.
- Branch scopes are deeper than the enclosing function body. This matters for
  the mutable-return lifetime check.
- The global overload table is not a normal nested-scope table. It is consulted
  only when the innermost symbol with that name is global and has function
  type.
- A local function may not shadow a visible name at all, while a local variable
  may shadow it.
- Unknown-symbol suggestions are collected from all live scopes, not only the
  innermost one; the closest edit distance wins, with a lexical tie-break.

## Diagnostics

- [ERR-errUnknownSymbol](../errors/errUnknownSymbol.md#ERR-errUnknownSymbol)
- [ERR-errRedeclaration](../errors/errRedeclaration.md#ERR-errRedeclaration)
- [ERR-errFuncRedefinition](../errors/errFuncRedefinition.md#ERR-errFuncRedefinition)
- [ERR-errContextScope](../errors/errContextScope.md#ERR-errContextScope)
- [ERR-errReturnDanglingMutable](../errors/errReturnDanglingMutable.md#ERR-errReturnDanglingMutable)

## Tests and implementation

- `tests/tSema.nim`: unknown-symbol suggestions from current and outer scopes
- `tests/tFunc.nim`: nested function name conflicts, scoped declarations
- `src/visitors/sema.nim`: `Scope`, `pushScope`, `popScope`, `newSymbol`,
  `symbolExists`, `getSymbol`, `getGlobalOverloads`, `isLoopContext`,
  `isFuncContext`