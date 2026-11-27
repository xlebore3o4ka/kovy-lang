# ERR-errFuncRedefinition

<!-- doc-id: ERR-errFuncRedefinition -->
<!-- kind: errFuncRedefinition -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errFuncRedefinition"></a>
## Message

Locale key: `errFuncRedefinition`.

```text
Function @q0 is already declared
```

| Placeholder | Meaning |
|---|---|
| `@q0` | function name |

No addinfo.

## Emitters

- `Sema.visit(FuncDecl)`, global duplicate forward: a bodyless declaration has
  the same parameter types **and** the same return type as an existing,
  still-undefined overload. The earlier forward remains undefined.
- `Sema.visit(FuncDecl)`, duplicate definition: a definition has the same
  parameter types and the same return type as an existing, already-defined
  overload.
- `Sema.visit(FuncDecl)`, bodyless declaration after a definition: same
  parameter types and same return type.
- `Sema.visit(FuncDecl)`, nested function: the name already exists as a visible
  function symbol. Nested functions cannot be overloaded, so even a different
  parameter list is rejected this way.

A global function whose name collides with a **non-function** symbol uses
`ERR-errRedeclaration` instead. A same-parameter function with a different
return type uses `ERR-errOverloadByReturnType`.

## Triggers

<a id="TRG-errFuncRedefinition-duplicate-definition"></a>
### TRG-errFuncRedefinition-duplicate-definition

<!-- expect-errors: errFuncRedefinition -->
```kovy
int f():
  return 1
int f():
  return 2
```

Both definitions have the same parameter types and return type.

<a id="TRG-errFuncRedefinition-duplicate-forward"></a>
### TRG-errFuncRedefinition-duplicate-forward

<!-- expect-errors: errFuncRedefinition, errUnresolvedForward -->
```kovy
int f(int a)
int f(int a)
```

The second forward repeats the first. The first is never defined, so `finalize`
also reports `errUnresolvedForward`.

<a id="TRG-errFuncRedefinition-forward-after-definition"></a>
### TRG-errFuncRedefinition-forward-after-definition

<!-- expect-errors: errFuncRedefinition -->
```kovy
int f():
  return 1
int f()
```

The bodyless declaration matches the already-defined overload.

<a id="TRG-errFuncRedefinition-nested-overload"></a>
### TRG-errFuncRedefinition-nested-overload

<!-- expect-errors: errFuncRedefinition -->
```kovy
void outer():
  void r():
    int x = 1
  void r(int a):
    int y = 2
```

Nested functions may not be overloaded.

<a id="TRG-errFuncRedefinition-nested-same-signature"></a>
### TRG-errFuncRedefinition-nested-same-signature

<!-- expect-errors: errFuncRedefinition -->
```kovy
void outer():
  void r():
    int x = 1
  void r():
    int y = 2
```

The nested name is already visible as a function.

<a id="TRG-errFuncRedefinition-nested-visible-function"></a>
### TRG-errFuncRedefinition-nested-visible-function

<!-- expect-errors: errFuncRedefinition -->
```kovy
int g():
  return 1
void outer():
  void g():
    int x = 1
```

A nested function may not shadow an outer function name.

## Near misses

- A global function after a variable with the same name is
  `ERR-errRedeclaration` through `rejectNonFunctionName`.
- A nested function after a variable or parameter with the same name is also
  `ERR-errRedeclaration`; only an existing function symbol reaches this kind.
- A duplicate declaration with the same parameter types but a different return
  type is `ERR-errOverloadByReturnType`.
- A global forward plus a definition with different parameter types is an
  unresolved forward, not a redefinition.

## Cascades

The declaration is rejected and not analyzed further. A duplicate forward
does not replace or define the earlier overload, so `finalize` can add
`errUnresolvedForward`. A rejected nested function skips its parameter and body
analysis. Later statements in the enclosing block continue.

## Tests

- `tests/tFunc.nim`: duplicate definitions, nested function names, and forward
  redeclarations

## Related

- [SEM-FUNC-FORWARD](../language/functions.md#SEM-FUNC-FORWARD)
- [SEM-SCOPE-FUNCTIONS](../language/scopes.md#SEM-SCOPE-FUNCTIONS)
- [ERR-errRedeclaration](errRedeclaration.md#ERR-errRedeclaration)
- [ERR-errOverloadByReturnType](errOverloadByReturnType.md#ERR-errOverloadByReturnType)
- [ERR-errUnresolvedForward](errUnresolvedForward.md#ERR-errUnresolvedForward)