# ERR-errNotCallable

<!-- doc-id: ERR-errNotCallable -->
<!-- kind: errNotCallable -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errNotCallable"></a>
## Message

Locale key: `errNotCallable`.

```text
Expression @c0 is not callable
```

| Placeholder | Meaning |
|---|---|
| `@c0` | callee expression via `Expr.toStr` |

No addinfo.

## Emitters

- `Sema.visit(Call)`, generic path: after visiting the callee and stripping one
  `typeMutable` wrapper, the base type is not `typeFunc`.

The check is not reached when the callee visit returns `typeError`; an unknown
name in callee position is therefore `ERR-errUnknownSymbol` only. A symbol with
more than one global overload takes the overload-resolution path instead.

## Triggers

<a id="TRG-errNotCallable-variable"></a>
### TRG-errNotCallable-variable

<!-- expect-errors: errNotCallable -->
```kovy
int x = 1
int y = x(2)
```

`x` has type `int`, not a function type. All arguments are still visited
before the diagnostic is added.

<a id="TRG-errNotCallable-literal"></a>
### TRG-errNotCallable-literal

<!-- expect-errors: errNotCallable -->
```kovy
int y = 1(2)
```

`1` is a `numberLiteral`. The parser accepts any postfix expression followed
by an argument list; sema decides callability.

<a id="TRG-errNotCallable-pointer"></a>
### TRG-errNotCallable-pointer

<!-- expect-errors: errNotCallable -->
```kovy
int* p = alloc 1 of int
int y = p(1)
```

A pointer is not a function type. To call a function through a pointer, the
pointer must have a function pointee such as `int(int)*`.

<a id="TRG-errNotCallable-void"></a>
### TRG-errNotCallable-void

<!-- expect-errors: errNotCallable -->
```kovy
void x
int y = x(1)
```

`void` is a type, not a callable value.

## Near misses

- A bare `int` / `bool` / `void` keyword in callee position is a parser error,
  not `errNotCallable`.
- An unknown callee is `ERR-errUnknownSymbol`; the call returns `typeError`
  without this diagnostic.
- A function-typed symbol or a pointer to a function type is callable.
- A mutable symbol whose inner type is a function type is callable; one
  mutable wrapper is stripped before the check.

## Cascades

The call returns `typeError`; an enclosing declaration does not add
`errDoesNotFit`, and the arguments do not get argument-mismatch checks. The
callee expression is still visited, so an error in the callee itself can be
reported first. If the callee is a local symbol whose type is `typeError`, the
call stops at the callee error.

## Tests

- `tests/tFunc.nim`: function values and void calls
- `tests/tPtr.nim`: function pointers and indirect calls

## Related

- [SEM-FUNC-CALL](../language/functions.md#SEM-FUNC-CALL)
- [SYN-EXPR-CALL](../language/expressions.md#SYN-EXPR-CALL)
- [ERR-errWrongArity](errWrongArity.md#ERR-errWrongArity)
- [ERR-errArgMismatch](errArgMismatch.md#ERR-errArgMismatch)
- [ERR-errUnknownSymbol](errUnknownSymbol.md#ERR-errUnknownSymbol)