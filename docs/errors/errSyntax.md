# ERR-errSyntax

<!-- doc-id: ERR-errSyntax -->
<!-- kind: errSyntax -->
<!-- status: emitted -->
<!-- phase: parser -->

<a id="ERR-errSyntax"></a>
## Message

Locale key: `errSyntax`.

```text
Syntax error, expected @0, got @1
  Expected syntax: @c2
```

| Placeholder | Meaning |
|---|---|
| `@0` | expected token description |
| `@1` | actual token description |
| `@2` | expected syntax fragment |

One emitter branch calls `newError` with no placeholders. Its formatted message
is therefore truncated to `Syntax error, expected , got ` with an empty
`Expected syntax:` addinfo. See
[TRG-errSyntax-missing-comma-parameters](#TRG-errSyntax-missing-comma-parameters).

## Emitters

- `Parser.expect`: when a required token kind is absent.
- `parseStmts`: when a simple statement is not followed by `EOS`, `EOF`, or
  dedent, and the next token is not `INDENT`.
- `parseBlock`: when an inline block is not followed by `EOS`, `EOF`, or
  dedent.
- `parseFuncDecl`: when a parameter group ends without a comma and the next
  token is not `)`, `EOF`, or a new parameter type. This call supplies no
  placeholders and is the malformed-message case.

`expect` is used for the colon after `if`/`elif`/`else`/`while`, function
bodies and function types; `(`, `)`, `[`, `]`; commas in calls, arrays,
parameter lists, and function types; the `of` in `alloc`; declaration names;
and parameter names.

## Triggers

<a id="TRG-errSyntax-missing-colon"></a>
### TRG-errSyntax-missing-colon

<!-- expect-errors: errSyntax -->
```kovy
if true
  int x = 1
```

`parseBlock` calls `expect(tkColon, ...)`. The parser skips to the next
separator after recording the error, so the indented statement is not parsed.

<a id="TRG-errSyntax-missing-close-delimiter"></a>
### TRG-errSyntax-missing-close-delimiter

<!-- expect-errors: errSyntax -->
```kovy
int* p = [1, 2
```

The array parser reaches `EOF` while expecting `]`. Missing `)` in a grouped
expression, call, parameter list, or function type uses the same emitter.

<a id="TRG-errSyntax-missing-separator"></a>
### TRG-errSyntax-missing-separator

<!-- expect-errors: errSyntax -->
```kovy
int x = 1 int y = 2
```

`parseStmts` sees another statement start where it requires `EOS`. The expected
fragment is the newline-or-semicolon message.

<a id="TRG-errSyntax-inline-block-missing-eos"></a>
### TRG-errSyntax-inline-block-missing-eos

<!-- expect-errors: errSyntax -->
```kovy
if true: int x = 1 int y = 2
```

The inline body parses one declaration, then finds `int` instead of `EOS`.
This is the `parseBlock` branch, not the `parseStmts` branch.

<a id="TRG-errSyntax-missing-comma-parameters"></a>
### TRG-errSyntax-missing-comma-parameters

<!-- expect-errors: errSyntax -->
```kovy
int f(int a bool b):
  return a
```

After parameter `a`, the next token is `bool` rather than comma, `)`, or EOF.
The final `parseFuncDecl` check reports the error with no placeholders, so the
localized message is truncated. This is current behaviour.

<a id="TRG-errSyntax-bad-name"></a>
### TRG-errSyntax-bad-name

<!-- expect-errors: errSyntax -->
```kovy
int = 1
```

A declaration requires an identifier after its type.

<a id="TRG-errSyntax-missing-of"></a>
### TRG-errSyntax-missing-of

<!-- expect-errors: errSyntax -->
```kovy
int* p = alloc 4
```

The general allocation form requires `of` and an element type.

<a id="TRG-errSyntax-missing-comma-type-arguments"></a>
### TRG-errSyntax-missing-comma-type-arguments

<!-- expect-errors: errSyntax, errSyntax -->
```kovy
int(int bool) f
```

The function type expects a comma after its first argument type. Recovery
skips to the end of the line, and the declaration parser then also fails to
find its identifier. Two syntax errors are produced.

## Near misses

- A trailing comma in call arguments, parameters, array literals, and function
  type arguments is accepted.
- A function declaration without `:` is a valid forward declaration, not a
  missing-colon syntax error.
- An empty indented branch body is accepted; an empty function body with a
  colon is `ERR-errEmptyFunctionBody`.

## Cascades

Parser recovery skips tokens to the next `EOS`, `EOF`, or dedent after most
syntax errors. This often suppresses follow-on parser errors, but recovery can
also cause a second independent error, as in the function-type example. A
syntax error replaces the failed construct with an invalid node; sema normally
adds nothing for it.

## Tests

- Parser syntax is exercised indirectly by all tests.
- No test asserts every `expect` call site; the documentation checker runs
  the reproducers above.

## Related

- [KOVY-GRAMMAR](../language/grammar.md#KOVY-GRAMMAR)
- [ERR-errTypeSyntax](errTypeSyntax.md#ERR-errTypeSyntax)
- [ERR-errExpressionExpected](errExpressionExpected.md#ERR-errExpressionExpected)
- [ERR-errStatementExpected](errStatementExpected.md#ERR-errStatementExpected)