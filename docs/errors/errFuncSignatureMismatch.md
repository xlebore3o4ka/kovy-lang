# ERR-errFuncSignatureMismatch

<!-- doc-id: ERR-errFuncSignatureMismatch -->
<!-- kind: errFuncSignatureMismatch -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errFuncSignatureMismatch"></a>
## Message

Locale key: `errFuncSignatureMismatch`.

```text
Definition of @q0 does not match its forward declaration
  Forward: @c1
  Definition: @c2
```

| Placeholder | Meaning |
|---|---|
| `@q0` | function name |
| `@c1` | forward signature via `signatureStr` |
| `@c2` | definition signature via `signatureStr` |

`signatureStr` prints `mut ` before a mutable return type or parameter, then
the type, name, and comma-separated `[mut ]T name` parameters.

## Emitters

- `Sema.visit(FuncDecl)`: a definition matches a recorded, still-undefined
  overload by parameter types, but either the full signature differs (the
  return type) or the parameter **names** differ.

`findOverload` compares parameter types only. Once an overload is found, the
definition must match the complete signature and every parameter name.

When this error is reported, the overload is marked `defined` so `finalize`
does not also report it as unresolved. The definition is not attached to the
overload.

## Triggers

<a id="TRG-errFuncSignatureMismatch-parameter-name"></a>
### TRG-errFuncSignatureMismatch-parameter-name

<!-- expect-errors: errFuncSignatureMismatch -->
```kovy
int f(int a)
int f(int b):
  return b
```

Nim resolves a forward and definition as one proc only when parameter names
match, so Kovy enforces the same rule.

<a id="TRG-errFuncSignatureMismatch-return-type"></a>
### TRG-errFuncSignatureMismatch-return-type

<!-- expect-errors: errFuncSignatureMismatch -->
```kovy
int f(int a)
bool f(int a):
  return true
```

Parameter types match, but the return type differs.

<a id="TRG-errFuncSignatureMismatch-mutable-return"></a>
### TRG-errFuncSignatureMismatch-mutable-return

<!-- expect-errors: errFuncSignatureMismatch -->
```kovy
int f(int a)
int mut f(int a):
  return a
```

The mutable wrapper is part of the signature, so it must match exactly.

## Near misses

- A definition with a different **number** of parameters does not match
  `findOverload`; it becomes a new overload and the forward is left
  `ERR-errUnresolvedForward`.
- A definition with different parameter types, including different parameter
  mutability, also becomes a new overload and leaves the forward unresolved.
  `sameParams` compares parameter types exactly, so parameter mutability cannot
  reach this error.
- A definition with exactly the same signature and parameter names completes
  the forward without an error.
- A duplicate definition or duplicate forward with the same parameters and the
  same return type is `ERR-errFuncRedefinition`.
- A second declaration with the same parameters but a different return type is
  `ERR-errOverloadByReturnType` when both declarations are forwards or both are
  definitions.

## Cascades

The error is attached to the definition's function token. The definition is
not analyzed further: parameter scopes, body analysis, and all-paths-return
checks are skipped. The earlier forward remains in the overload table with
`defined = true`, so it is callable but code generation would not have a body
for it. This is the current state; the test driver does not run nimgen when any
error exists.

## Tests

- `tests/tFunc.nim`: parameter-name and return-type mismatches
- `tests/tFunc.nim`: forward matching and unresolved forwards

## Related

- [SEM-FUNC-FORWARD](../language/functions.md#SEM-FUNC-FORWARD)
- [ERR-errFuncRedefinition](errFuncRedefinition.md#ERR-errFuncRedefinition)
- [ERR-errOverloadByReturnType](errOverloadByReturnType.md#ERR-errOverloadByReturnType)
- [ERR-errUnresolvedForward](errUnresolvedForward.md#ERR-errUnresolvedForward)