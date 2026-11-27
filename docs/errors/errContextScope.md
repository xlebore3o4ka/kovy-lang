# ERR-errContextScope

<!-- doc-id: ERR-errContextScope -->
<!-- kind: errContextScope -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errContextScope"></a>
## Message

Locale key: `errContextScope`.

```text
@q0 statement outside @q1 context
```

| Placeholder | Meaning |
|---|---|
| `@q0` | keyword: `break`, `continue`, or `return` |
| `@q1` | context kind: `loop` or `func` |

No addinfo.

## Emitters

- `Sema.visit(Break)`: no visible loop context.
- `Sema.visit(Continue)`: no visible loop context.
- `Sema.visit(Return)`: no visible function context.

A function boundary stops loop-context lookup. A `break` or `continue` inside
a function declared inside a loop is therefore outside the loop. A `return`
inside a nested function targets the innermost function and is valid.

## Triggers

<a id="TRG-errContextScope-break-global"></a>
### TRG-errContextScope-break-global

<!-- expect-errors: errContextScope -->
```kovy
break
```

There is no loop and no function.

<a id="TRG-errContextScope-continue-global"></a>
### TRG-errContextScope-continue-global

<!-- expect-errors: errContextScope -->
```kovy
continue
```

The same loop-context check applies to `continue`.

<a id="TRG-errContextScope-return-global"></a>
### TRG-errContextScope-return-global

<!-- expect-errors: errContextScope -->
```kovy
return;
```

The semicolon supplies the `EOS` needed for a bare `return`. Without a
following separator, the parser instead attempts to parse a return expression
and can produce `ERR-errExpressionExpected`.

<a id="TRG-errContextScope-break-in-function"></a>
### TRG-errContextScope-break-in-function

<!-- expect-errors: errContextScope -->
```kovy
void f():
  break
```

A function context is not a loop context.

<a id="TRG-errContextScope-break-in-nested-function"></a>
### TRG-errContextScope-break-in-nested-function

<!-- expect-errors: errContextScope -->
```kovy
int mut i = 0
while i < 3:
  void inner():
    break
  i = i + 1
```

The nested function starts a new execution context. The surrounding loop is
not visible for loop control.

## Near misses

- `break` inside a branch inside a loop is accepted.
- `continue` inside a nested loop belongs to the nested loop.
- `return` inside a nested function is valid.
- `alloc` inside a nested function declared in a loop is allowed, because the
  loop-context lookup also stops at a function boundary.

## Cascades

The statement visitor returns false, but block visiting continues. A rejected
`break` does not alter all-paths-return analysis of an enclosing function
unless it also makes a `while true` body contain a syntactic break; the AST
still contains the `Break` node. A rejected global `return` still counts as a
return for block unreachable detection, which can produce
`ERR-errUnreachableCode` if more statements follow.

## Tests

- `tests/tSema.nim`: break inside a function declared in a loop
- `tests/tFunc.nim`: valid `while true` and break uses

## Related

- [SEM-SCOPE-CONTEXT](../language/scopes.md#SEM-SCOPE-CONTEXT)
- [SEM-FLOW-CONTEXT](../language/control-flow.md#SEM-FLOW-CONTEXT)
- [SYN-STMT-BREAK](../language/statements.md#SYN-STMT-BREAK)
- [SYN-STMT-RETURN](../language/statements.md#SYN-STMT-RETURN)