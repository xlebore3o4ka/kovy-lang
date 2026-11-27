# ERR-errEmptyFunctionBody

<!-- doc-id: ERR-errEmptyFunctionBody -->
<!-- kind: errEmptyFunctionBody -->
<!-- status: emitted -->
<!-- phase: parser -->

<a id="ERR-errEmptyFunctionBody"></a>
## Message

Locale key: `errEmptyFunctionBody`.

```text
Function body cannot be empty
  A function must contain at least one statement
```

No placeholders.

## Emitters

- `Parser.parseBlock` with `requireBody = true`: after the colon, the next
  token is `EOS`, `EOF`, or `DEDENT`.
- `Parser.parseBlock` with `requireBody = true`: after an indented block has
  been read, its statement list is empty.

The second check is defensive. The lexer only emits `INDENT` when a non-blank
line follows, so an indented function body with no statements is difficult to
construct from source. The first check covers the practical cases.

## Triggers

<a id="TRG-errEmptyFunctionBody-after-colon"></a>
### TRG-errEmptyFunctionBody-after-colon

<!-- expect-errors: errEmptyFunctionBody -->
```kovy
void f():
```

The token after `:` is an end of statement / EOF. A function with a colon must
have at least one body statement.

<a id="TRG-errEmptyFunctionBody-blank-body"></a>
### TRG-errEmptyFunctionBody-blank-body

<!-- expect-errors: errEmptyFunctionBody -->
```kovy
void f():
   
```

Whitespace-only lines do not create an indented block.

<a id="TRG-errEmptyFunctionBody-before-next-declaration"></a>
### TRG-errEmptyFunctionBody-before-next-declaration

<!-- expect-errors: errEmptyFunctionBody -->
```kovy
void f():
void g():
  int x = 1
```

The colon is followed immediately by the next declaration. The parser reports
the empty body and recovers.

## Near misses

- `void f(): int x = 1` is a valid inline one-statement body.
- `void f()` without a colon is a forward declaration, not an empty body.
- Empty indented `if`, `elif`, `else`, and `while` bodies are accepted; only
  functions require a non-empty body.

## Cascades

The failing function declaration is replaced by an invalid statement, so sema
does not check its return paths, parameters at the body level, or code
generation. The minimal reproducers add only this error. Recovery may skip the
next line, as in the third trigger, but no sema error results.

## Tests

- `tests/tFunc.nim`: `"empty function body is rejected"`

## Related

- [SYN-FUNC-DECL](../language/functions.md#SYN-FUNC-DECL)
- [SYN-GRAMMAR-BLOCK](../language/grammar.md#SYN-GRAMMAR-BLOCK)
- [SEM-INDENT-BLOCK](../language/indentation.md#SEM-INDENT-BLOCK)