# ERR-errUnreachableCode

<!-- doc-id: ERR-errUnreachableCode -->
<!-- kind: errUnreachableCode -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errUnreachableCode"></a>
## Message

Locale key: `errUnreachableCode`.

```text
Unreachable code from line @0 to line @1
```

| Placeholder | Meaning |
|---|---|
| `@0` | `founder.token.line + 1` |
| `@1` | line of the last statement in the block |

Neither placeholder uses a modifier. No addinfo.

## Emitters

- `Sema.visit(Block)`: after visiting a statement that makes
  `controlAllReturnPaths` true, every later statement in the same block is
  unreachable. One diagnostic is added at the founding statement.

The check is per block. Each `Block` node—a function body, branch body, loop
body—maintains its own founder. A later founding statement in the same block
does not add a second diagnostic.

Later statements are still visited and checked, so their own errors can also
appear.

## Triggers

<a id="TRG-errUnreachableCode-after-return"></a>
### TRG-errUnreachableCode-after-return

<!-- expect-errors: errUnreachableCode -->
```kovy
int f():
  return 1
  int x = 2
```

The founder is the `return` at line 2, so the reported range begins at line 3.
The last statement is at line 3, giving `from line 3 to line 3`.

<a id="TRG-errUnreachableCode-multiple-followers"></a>
### TRG-errUnreachableCode-multiple-followers

<!-- expect-errors: errUnreachableCode -->
```kovy
int f():
  return 1
  int x = 2
  int y = 3
```

The range extends to the last statement: `from line 3 to line 4`.

<a id="TRG-errUnreachableCode-after-while-true"></a>
### TRG-errUnreachableCode-after-while-true

<!-- expect-errors: errUnreachableCode -->
```kovy
int f():
  while true:
    int x = 1
  int y = 2
```

`while true` without a visible `break` makes the rest of the block
unreachable.

<a id="TRG-errUnreachableCode-after-exhaustive-if"></a>
### TRG-errUnreachableCode-after-exhaustive-if

<!-- expect-errors: errUnreachableCode -->
```kovy
int f(int x):
  if x > 0:
    return 1
  else:
    return 2
  int y = 3
```

An `if`/`else` whose every body returns is a founder.

<a id="TRG-errUnreachableCode-in-branch"></a>
### TRG-errUnreachableCode-in-branch

<!-- expect-errors: errUnreachableCode -->
```kovy
int f(int x):
  if x > 0:
    return 1
    int y = 2
  return 0
```

The branch body is its own block, so it reports independently of the function
body.

<a id="TRG-errUnreachableCode-nested-blocks"></a>
### TRG-errUnreachableCode-nested-blocks

<!-- expect-errors: errUnreachableCode, errUnreachableCode -->
```kovy
int f():
  return 1
  if true:
    return 2
    int y = 3
```

The outer block reports the `if` and following statements as unreachable. The
`if` body is still visited and reports its own unreachable statement, so two
diagnostics are produced.

## Near misses

- A `return` that is the last statement of its block makes nothing
  unreachable.
- `break`, `continue`, and ordinary expression statements are not founders,
  because `controlAllReturnPaths` does not treat them as guaranteed returns.
- A rejected `return` still counts as a `Return` node for this analysis.
- A `while true` with a syntactic `break` is not a founder.
- A `while 1 == 1` loop is not a founder, because only the literal boolean
  `true` is recognized.
- A function declared after a founder is a normal statement; it is still
  visited even though it is reported as unreachable.

## Cascades

The diagnostic is added at the founder, not at the first unreachable statement.
Unreachable statements can produce their own errors, and a nested block can add
its own unreachable diagnostic. All-paths-return analysis is unaffected by
unreachable-code detection: a function with an early return is accepted as long
as the block-level proof succeeds.

## Tests

- `tests/tFunc.nim`: statements after `return`
- Documentation reproducers: above

## Related

- [SEM-FLOW-UNREACHABLE](../language/control-flow.md#SEM-FLOW-UNREACHABLE)
- [SEM-FLOW-RETURN-PATHS](../language/control-flow.md#SEM-FLOW-RETURN-PATHS)
- [ERR-errNotAllPathsReturn](errNotAllPathsReturn.md#ERR-errNotAllPathsReturn)