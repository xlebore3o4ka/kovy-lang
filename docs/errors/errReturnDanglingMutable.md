# ERR-errReturnDanglingMutable

<!-- doc-id: ERR-errReturnDanglingMutable -->
<!-- kind: errReturnDanglingMutable -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errReturnDanglingMutable"></a>
## Message

Locale key: `errReturnDanglingMutable`.

```text
Cannot return mutable symbol @q0: its lifetime does not exceed the function scope
  Declared in file @f1, line @2
```

| Placeholder | Meaning |
|---|---|
| `@q0` | source symbol name |
| `@f1` | file id of the symbol declaration |
| `@2` | line of the symbol declaration |

No other addinfo.

## Emitters

- `Sema.visit(Return)`: the function returns a mutable type, the returned
  expression has a mutable type, and the symbol that supplies the mutability
  has a lexical scope depth greater than the function's parameter scope.

The symbol is found by `getMutabilitySource`, which follows:

| Expression | Step |
|---|---|
| assignment `=` | left side |
| unary `#`, `addr`, `+`, `-`, `not` | operand |
| call | callee symbol |
| symbol | itself |

Anything else would be a compiler-internal exception rather than a source
diagnostic; current sema only calls this path for mutable symbols, so the
ordinary mutable sources are covered.

## Triggers

<a id="TRG-errReturnDanglingMutable-local"></a>
### TRG-errReturnDanglingMutable-local

<!-- expect-errors: errReturnDanglingMutable -->
```kovy
int mut f():
  int mut x = 1
  return x
```

`x` is declared in the function body, which is deeper than the parameter scope.

<a id="TRG-errReturnDanglingMutable-branch-local"></a>
### TRG-errReturnDanglingMutable-branch-local

<!-- expect-errors: errReturnDanglingMutable, errNotAllPathsReturn -->
```kovy
int mut f():
  int mut x = 1
  if true:
    return x
```

The branch body is deeper still. The `if` has no `else`, so the separate
all-paths-return analysis also reports `errNotAllPathsReturn`.

<a id="TRG-errReturnDanglingMutable-call-result"></a>
### TRG-errReturnDanglingMutable-call-result

<!-- expect-errors: errReturnDanglingMutable -->
```kovy
int mut outer(int mut p):
  int mut inner():
    return p
  return inner()
```

The call result is mutable. `getMutabilitySource` follows the callee symbol
`inner`, which is a nested local declared in the outer body, so its depth is
greater than `outer`'s parameter scope. This is a current quirk: the value
actually originates from the parameter `p`, which would be safe.

## Near misses

- Returning a mutable parameter is allowed; its scope equals the parameter
  scope.
- Returning a mutable global is allowed; its depth is 0.
- Returning a nested function's call result is allowed when that function is
  global, because the callee symbol's depth is 0.
- Returning an `int*` local pointer is not covered by this check at all; see
  [SEM-PTR-LIFETIME](../language/pointers.md#SEM-PTR-LIFETIME).
- Returning an immutable value from a mutable function is
  `ERR-errImmutableReturn`.

## Cascades

The check runs only after the value fits the return type. It reports once and
returns false for that statement. The `Return` node is still present for
all-paths-return and unreachable analysis. Other statements in the function
continue to be visited.

## Tests

- `tests/tFunc.nim`: mutable local return rejection
- `tests/tPtr.nim`: mutable-pointer lifetime cases and accepted escapes

## Related

- [SEM-FLOW-RETURN-DANGLING](../language/control-flow.md#SEM-FLOW-RETURN-DANGLING)
- [SEM-PTR-LIFETIME](../language/pointers.md#SEM-PTR-LIFETIME)
- [ERR-errImmutableReturn](errImmutableReturn.md#ERR-errImmutableReturn)