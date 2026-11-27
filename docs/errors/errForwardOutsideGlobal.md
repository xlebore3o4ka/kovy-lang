# ERR-errForwardOutsideGlobal

<!-- doc-id: ERR-errForwardOutsideGlobal -->
<!-- kind: errForwardOutsideGlobal -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errForwardOutsideGlobal"></a>
## Message

Locale key: `errForwardOutsideGlobal`.

```text
Forward declaration of @q0 is only allowed at global scope
```

| Placeholder | Meaning |
|---|---|
| `@q0` | function name |

No addinfo.

## Emitters

- `Sema.visit(FuncDecl)`: the function has no body and the current lexical
  scope is not the global scope.

The check runs before any parameter or body analysis. A bodyless declaration is
parsed as a forward whenever the declaration has no `:` and block. This is
true even on the same line, so `void outer(): void inner()` is a nested
forward, not an empty body.

## Triggers

<a id="TRG-errForwardOutsideGlobal-function-body"></a>
### TRG-errForwardOutsideGlobal-function-body

<!-- expect-errors: errForwardOutsideGlobal -->
```kovy
void outer():
  void inner()
  int x = 1
```

`inner` is declared inside `outer` without a body. Following statements in
`outer` are still visited.

<a id="TRG-errForwardOutsideGlobal-inline"></a>
### TRG-errForwardOutsideGlobal-inline

<!-- expect-errors: errForwardOutsideGlobal -->
```kovy
void outer(): void inner()
```

The bodyless nested function is the inline body statement of `outer`.

<a id="TRG-errForwardOutsideGlobal-nested-in-loop"></a>
### TRG-errForwardOutsideGlobal-nested-in-loop

<!-- expect-errors: errForwardOutsideGlobal -->
```kovy
while false:
  void inner()
```

A loop body is not global scope either.

## Near misses

- A bodyless function at global scope is a valid forward declaration.
- A nested function **with** a body is valid; nested functions simply cannot be
  overloaded.
- A colon followed by no body statement is `ERR-errEmptyFunctionBody`, not this
  error.
- A bodyless nested function is rejected before a possible name collision is
  checked.

## Cascades

The visitor returns false immediately, so the nested forward's parameters are
not visited and its body does not exist. The enclosing block continues.
No unresolved-forward diagnostic is produced, because the rejected declaration
never enters the forward list.

## Tests

- `tests/tFunc.nim`: nested function declarations

## Related

- [SEM-FUNC-FORWARD](../language/functions.md#SEM-FUNC-FORWARD)
- [SYN-FUNC-DECL](../language/functions.md#SYN-FUNC-DECL)
- [ERR-errUnresolvedForward](errUnresolvedForward.md#ERR-errUnresolvedForward)
- [ERR-errEmptyFunctionBody](errEmptyFunctionBody.md#ERR-errEmptyFunctionBody)