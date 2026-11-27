# ERR-errRedeclaration

<!-- doc-id: ERR-errRedeclaration -->
<!-- kind: errRedeclaration -->
<!-- status: emitted -->
<!-- phase: parser, sema -->

<a id="ERR-errRedeclaration"></a>
## Message

Locale key: `errRedeclaration`.

```text
Redeclaring the @q0 symbol
  Last declared in file @f1, line @2
```

| Placeholder | Meaning |
|---|---|
| `@q0` | the duplicated name |
| `@f1` | file id of the earlier declaration |
| `@2` | line of the earlier declaration |

## Emitters

- `Parser.parseDecl`: the same name appears twice inside one variable
  declaration group.
- `Sema.visit(Decl)`: the name already exists in the current lexical scope.
- `Sema.visit(FuncDecl)`, while visiting parameter declarations: duplicate
  parameter names in the parameter scope use the same `Decl` path.

- `Sema.visit(FuncDecl)`, `rejectNonFunctionName`: a global or nested function
  declaration collides with a visible non-function symbol.

`rejectNonFunctionName` reports this kind. A collision between two functions
uses `ERR-errFuncRedefinition` instead.

## Triggers

<a id="TRG-errRedeclaration-parser-group"></a>
### TRG-errRedeclaration-parser-group

<!-- expect-errors: errRedeclaration -->
```kovy
int x = 1, x = 2
```

The parser detects the duplicate before building a usable declaration and
returns an invalid statement. The earlier token supplies the addinfo.

<a id="TRG-errRedeclaration-same-scope"></a>
### TRG-errRedeclaration-same-scope

<!-- expect-errors: errRedeclaration -->
```kovy
int x = 1
int x = 2
```

The second declaration sees the first in the current global scope. Sema still
inserts the new symbol after reporting the error.

<a id="TRG-errRedeclaration-duplicate-parameter"></a>
### TRG-errRedeclaration-duplicate-parameter

<!-- expect-errors: errRedeclaration -->
```kovy
int f(int a, a):
  return a
```

Each parameter name becomes a separate `Decl`, so the parser does not catch
this; the parameter scope does.

<a id="TRG-errRedeclaration-variable-after-function"></a>
### TRG-errRedeclaration-variable-after-function

<!-- expect-errors: errRedeclaration -->
```kovy
int f():
  return 1
int f = 1
```

The variable declaration checks the current scope and finds the function
symbol. This is the ordinary declaration path, not the function-specific
checks.

<a id="TRG-errRedeclaration-function-after-variable"></a>
### TRG-errRedeclaration-function-after-variable

<!-- expect-errors: errRedeclaration -->
```kovy
int f = 1
int f():
  return 1
```

The function's name collides with a variable. `rejectNonFunctionName` reports
this kind, not `errFuncRedefinition`.

<a id="TRG-errRedeclaration-nested-function-after-variable"></a>
### TRG-errRedeclaration-nested-function-after-variable

<!-- expect-errors: errRedeclaration -->
```kovy
void outer():
  int g = 1
  void g():
    int x = 1
```

A nested function may not shadow a visible variable; this collision also uses
`rejectNonFunctionName`.

<a id="TRG-errRedeclaration-same-branch"></a>
### TRG-errRedeclaration-same-branch

<!-- expect-errors: errRedeclaration -->
```kovy
if true:
  int x = 1
  int x = 2
```

Branch scopes are ordinary lexical scopes for duplicate detection.

## Near misses

- A body local may shadow a parameter in the current implementation.
- A branch or loop local may shadow an outer name.
- A nested function may not shadow any visible name: a variable or parameter
  collision is this error, and a function collision is
  `errFuncRedefinition`.
- Two global functions with the same name use function-specific checks, not
  this error.

## Cascades

The parser duplicate aborts the declaration group and recovers to the next
separator, so no symbol is introduced by that group. The sema duplicate still
inserts the new symbol. In both cases the initializer is checked before the
duplicate check, so an initializer error can appear before this error.

## Tests

- `tests/tFunc.nim`: nested function conflicts
- `tests/tSema.nim`: scopes and shadowing

## Related

- [SEM-DECL-RULES](../language/declarations.md#SEM-DECL-RULES)
- [SEM-SCOPE-SHADOWING](../language/scopes.md#SEM-SCOPE-SHADOWING)
- [ERR-errFuncRedefinition](errFuncRedefinition.md#ERR-errFuncRedefinition)