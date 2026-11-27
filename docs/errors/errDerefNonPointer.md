# ERR-errDerefNonPointer

<!-- doc-id: ERR-errDerefNonPointer -->
<!-- kind: errDerefNonPointer -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errDerefNonPointer"></a>
## Message

Locale key: `errDerefNonPointer`.

```text
Cannot dereference a non-pointer value of type @c0
```

| Placeholder | Meaning |
|---|---|
| `@c0` | operand type before stripping mutability, via `diagnosticTypeStr` |

No addinfo.

## Emitters

- `Sema.visit(Unary)` with `tkHash`: after stripping one `typeMutable`
  wrapper, the operand type is not `typePtr`.

The diagnostic is attached to the operand token, not to `#`. The operand is
visited first; an error-typed operand returns before this check.

## Triggers

<a id="TRG-errDerefNonPointer-number"></a>
### TRG-errDerefNonPointer-number

<!-- expect-errors: errDerefNonPointer -->
```kovy
int x = #1
```

`numberLiteral` is not a pointer.

<a id="TRG-errDerefNonPointer-bool"></a>
### TRG-errDerefNonPointer-bool

<!-- expect-errors: errDerefNonPointer -->
```kovy
bool x = #true
```

`boolLiteral` is not a pointer.

<a id="TRG-errDerefNonPointer-mutable-scalar"></a>
### TRG-errDerefNonPointer-mutable-scalar

<!-- expect-errors: errDerefNonPointer -->
```kovy
int mut x = 1
int y = #x
```

The mutable wrapper is stripped, leaving `int`. The message displays the
original type, including the mutable marker.

<a id="TRG-errDerefNonPointer-function"></a>
### TRG-errDerefNonPointer-function

<!-- expect-errors: errDerefNonPointer -->
```kovy
int f():
  return 1
int x = #f
```

A function value is not a pointer. To call through a function pointer, declare
a pointer type such as `int()*`.

<a id="TRG-errDerefNonPointer-call-result"></a>
### TRG-errDerefNonPointer-call-result

<!-- expect-errors: errDerefNonPointer -->
```kovy
int f():
  return 1
int x = #f()
```

`f()` returns `int`, not a pointer. The parser groups this as `#(f())`.

## Near misses

- `#p` on any `T*` is accepted and yields `T`.
- `#[1, 2]` is accepted because an array literal has pointer type.
- `#(alloc 1 of int)` is accepted.
- Dereferencing a `void*` yields `void`, not this error; a later use of that
  value can still fail to fit a concrete declaration type.
- A call such as `#p()` parses as `#(p())`, so the dereference applies to the
  call result. Write `(#p)()` to call through a function pointer.

## Cascades

The expression returns `typeError`, suppressing an enclosing
`errDoesNotFit`. The operand's own diagnostics can precede this error. Write
access is only considered after the pointer check, so this error carries no
mutability information.

## Tests

- `tests/tPtr.nim`: dereference of pointers and non-pointers
- `tests/tPtr.nim`: `#` on array literals

## Related

- [SYN-EXPR-UNARY](../language/expressions.md#SYN-EXPR-UNARY)
- [SEM-PTR-RULES](../language/pointers.md#SEM-PTR-RULES)
- [ERR-errAddrFromImmutable](errAddrFromImmutable.md#ERR-errAddrFromImmutable)