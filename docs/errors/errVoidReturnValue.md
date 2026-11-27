# ERR-errVoidReturnValue

<!-- doc-id: ERR-errVoidReturnValue -->
<!-- kind: errVoidReturnValue -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errVoidReturnValue"></a>
## Message

Locale key: `errVoidReturnValue`.

```text
Cannot return a value from a void function
```

No placeholders and no addinfo.

## Emitters

- `Sema.visit(Return)`: a value is present and the innermost function's return
  type is `typeVoid`.

The return value is visited before this check. If that visit returns an error
type, `visit(Return)` stops before the void check, so the expression error is
reported alone.

## Triggers

<a id="TRG-errVoidReturnValue-literal"></a>
### TRG-errVoidReturnValue-literal

<!-- expect-errors: errVoidReturnValue -->
```kovy
void f():
  return 1
```

A `void` function cannot return a value.

<a id="TRG-errVoidReturnValue-expression"></a>
### TRG-errVoidReturnValue-expression

<!-- expect-errors: errVoidReturnValue -->
```kovy
void f():
  return 1 + 2
```

The expression type does not matter; the presence of any value is rejected.

## Near misses

- `void f(): return;` is valid. The semicolon supplies the `EOS` that makes the
  return bare.
- `int f(): return 1` is valid.
- A void call used as a statement is valid; only returning a value from the
  void function is rejected.

## Cascades

The check stops after adding this error and returns false. Blocks continue
visiting later statements, and all-paths-return analysis is not applied to a
void function. The return still counts as a control-path terminator for
unreachable-code detection.

## Tests

- `tests/tFunc.nim`: void function calls and void function values
- `tests/tPtr.nim`: function pointer returning void

## Related

- [SEM-FLOW-RETURN](../language/control-flow.md#SEM-FLOW-RETURN)
- [SYN-STMT-RETURN](../language/statements.md#SYN-STMT-RETURN)
- [SEM-TYPE-VOID](../language/types.md#SEM-TYPE-VOID)
- [ERR-errReturnValueExpected](errReturnValueExpected.md#ERR-errReturnValueExpected)