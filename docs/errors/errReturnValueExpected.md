# ERR-errReturnValueExpected

<!-- doc-id: ERR-errReturnValueExpected -->
<!-- kind: errReturnValueExpected -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errReturnValueExpected"></a>
## Message

Locale key: `errReturnValueExpected`.

```text
Expected return value of type @c0
```

| Placeholder | Meaning |
|---|---|
| `@c0` | declared return type via `Type.toStr` |

No addinfo.

## Emitters

- `Sema.visit(Return)`: no value is present and the innermost function's return
  type is not `void`.

## Triggers

<a id="TRG-errReturnValueExpected-int"></a>
### TRG-errReturnValueExpected-int

<!-- expect-errors: errReturnValueExpected -->
```kovy
int f():
  return;
```

The semicolon supplies the `EOS` that makes the return bare.

<a id="TRG-errReturnValueExpected-mutable"></a>
### TRG-errReturnValueExpected-mutable

<!-- expect-errors: errReturnValueExpected -->
```kovy
int mut f():
  return;
```

A mutable return type still requires a value.

<a id="TRG-errReturnValueExpected-pointer"></a>
### TRG-errReturnValueExpected-pointer

<!-- expect-errors: errReturnValueExpected -->
```kovy
int* f():
  return;
```

The diagnostic prints the declared pointer type.

## Near misses

- `void f(): return;` is valid.
- A newline at the end of a line normally supplies `EOS`, so this error is the
  common result for a bare `return` in a non-void function.
- If the source ends immediately after `return` with no newline or semicolon,
  the parser tries to parse a value first and can emit
  `ERR-errExpressionExpected`.
- If later statements follow a bare return, they can also be
  `ERR-errUnreachableCode`.

## Cascades

All-paths-return analysis treats the `Return` node as a return even though it
has no value, so this error does not also produce
`ERR-errNotAllPathsReturn`. Later statements in the same block can still be
unreachable.

## Tests

- `tests/tFunc.nim`: all-paths return and void returns

## Related

- [SEM-FLOW-RETURN](../language/control-flow.md#SEM-FLOW-RETURN)
- [SYN-STMT-RETURN](../language/statements.md#SYN-STMT-RETURN)
- [ERR-errVoidReturnValue](errVoidReturnValue.md#ERR-errVoidReturnValue)
- [ERR-errExpressionExpected](errExpressionExpected.md#ERR-errExpressionExpected)