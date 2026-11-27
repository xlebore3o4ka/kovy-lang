# ERR-errUnknownSymbol

<!-- doc-id: ERR-errUnknownSymbol -->
<!-- kind: errUnknownSymbol -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errUnknownSymbol"></a>
## Message

Locale key: `errUnknownSymbol`.

```text
Unknown symbol: @q0
  Perhaps you meant @q1?
```

| Placeholder | Meaning |
|---|---|
| `@q0` | the unresolved name |
| `@q1` | the best suggestion, or an empty string |

The addinfo is suppressed when the suggestion is empty.

## Emitters

- `Sema.visit(Symbol)`: the name is not present in any live scope.

The symbol lookup is documented in
[SEM-SCOPE-VISIBILITY](../language/scopes.md#SEM-SCOPE-VISIBILITY).

## Triggers

<a id="TRG-errUnknownSymbol-initializer"></a>
### TRG-errUnknownSymbol-initializer

<!-- expect-errors: errUnknownSymbol -->
```kovy
int x = missing
```

A declaration initializer is visited with the declared type as the expected
type; the unknown name is not a function overload and fails ordinary lookup.

<a id="TRG-errUnknownSymbol-use-before-declaration"></a>
### TRG-errUnknownSymbol-use-before-declaration

<!-- expect-errors: errUnknownSymbol -->
```kovy
int x = later
int later = 1
```

Names become visible only after their declaration entry is visited. A later
declaration in the same block does not retroactively resolve an earlier use.

<a id="TRG-errUnknownSymbol-out-of-scope"></a>
### TRG-errUnknownSymbol-out-of-scope

<!-- expect-errors: errUnknownSymbol -->
```kovy
if true:
  int hidden = 1
int x = hidden
```

The branch scope is popped when the `if` ends.

<a id="TRG-errUnknownSymbol-call"></a>
### TRG-errUnknownSymbol-call

<!-- expect-errors: errUnknownSymbol -->
```kovy
int x = missingFunction(1)
```

The callee is visited first. An unknown callee returns `typeError`, so the
call path does not add a separate not-callable error.

<a id="TRG-errUnknownSymbol-suggestion"></a>
### TRG-errUnknownSymbol-suggestion

<!-- expect-errors: errUnknownSymbol -->
```kovy
int counter = 1
int value = conter
```

Sema searches all currently live names by edit distance. Distances greater
than 2 produce no suggestion, so the addinfo is omitted. Ties prefer the
lexicographically smaller name.

## Near misses

- A function declared later is unknown unless a forward declaration was
  already seen.
- A name declared in a branch or loop is not visible after the construct.
- A type keyword in an expression position is a parser error, not an unknown
  symbol.
- An overloaded global function name has a symbol and can instead produce
  `ERR-errAmbiguousFunctionReference`.

## Cascades

Unknown symbols return `typeError`. Declarations treat `typeError` as fitting,
so the initializer does not also produce `errDoesNotFit`. Calls return the
error type without checking arity or arguments. A later declaration with the
same name can still be valid.

## Tests

- `tests/tSema.nim`: suggestion from current scope, outer scope, closest name,
  function name, and no distant suggestion
- `tests/tFunc.nim`: forward declarations

## Related

- [KOVY-SCOPES](../language/scopes.md#KOVY-SCOPES)
- [SEM-SCOPE-SHADOWING](../language/scopes.md#SEM-SCOPE-SHADOWING)
- [ERR-errAmbiguousFunctionReference](errAmbiguousFunctionReference.md#ERR-errAmbiguousFunctionReference)