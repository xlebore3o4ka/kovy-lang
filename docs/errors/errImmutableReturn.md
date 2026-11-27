# ERR-errImmutableReturn

<!-- doc-id: ERR-errImmutableReturn -->
<!-- kind: errImmutableReturn -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errImmutableReturn"></a>
## Message

Locale key: `errImmutableReturn`.

```text
Cannot return an immutable value from a mutable function
```

No placeholders and no addinfo.

## Emitters

- `Sema.visit(Return)`: the function's return type is `typeMutable` and the
  visited value's type is not `typeMutable`.

The check runs after the value visit and after the void-return check, but
before `fits`. It only compares the outer mutable wrapper, not the inner types.

## Triggers

<a id="TRG-errImmutableReturn-literal"></a>
### TRG-errImmutableReturn-literal

<!-- expect-errors: errImmutableReturn -->
```kovy
int mut f():
  return 1
```

A literal has an immutable type.

<a id="TRG-errImmutableReturn-immutable-local"></a>
### TRG-errImmutableReturn-immutable-local

<!-- expect-errors: errImmutableReturn -->
```kovy
int mut f():
  int x = 1
  return x
```

An immutable local is rejected even though it fits the inner `int`.

<a id="TRG-errImmutableReturn-immutable-call"></a>
### TRG-errImmutableReturn-immutable-call

<!-- expect-errors: errImmutableReturn -->
```kovy
int f():
  return 1
int mut g():
  return f()
```

A call returns mutable only when the callee's declared return type is mutable.
`f` returns plain `int`, so the result is immutable.

## Near misses

- Returning a mutable parameter, mutable local, mutable global, or mutable
  return value is accepted at this stage.
- A mutable call result is accepted here and then subject to
  `ERR-errReturnDanglingMutable`.
- A non-void function with a bare `return` is
  `ERR-errReturnValueExpected`; the immutable check is not reached.
- An error-typed value stops the return visit before any of these checks.

## Cascades

The check aborts the return statement; later statements are still visited.
Because the type mismatch is reported here rather than through `fits`, an
immutable value of an otherwise incompatible inner type also reports only this
error, not `errDoesNotFit`.

## Tests

- `tests/tFunc.nim`: mutable return types
- `tests/tPtr.nim`: mutable-returning function pointers

## Related

- [SEM-FLOW-RETURN](../language/control-flow.md#SEM-FLOW-RETURN)
- [KOVY-MUTABILITY](../language/mutability.md#KOVY-MUTABILITY)
- [ERR-errReturnDanglingMutable](errReturnDanglingMutable.md#ERR-errReturnDanglingMutable)
- [ERR-errDoesNotFit](errDoesNotFit.md#ERR-errDoesNotFit)