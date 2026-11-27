# ERR-errAmbiguousCall

<!-- doc-id: ERR-errAmbiguousCall -->
<!-- kind: errAmbiguousCall -->
<!-- status: emitted -->
<!-- phase: sema -->

<a id="ERR-errAmbiguousCall"></a>
## Message

Locale key: `errAmbiguousCall`.

```text
Ambiguous call to @q0 with arguments (@1)
  @2
```

| Placeholder | Meaning |
|---|---|
| `@q0` | function name |
| `@1` | actual argument types, comma-separated via `diagnosticTypeStr` |
| `@2` | one line per tied candidate via `overloadList` |

The addinfo is always present and starts on the line as printed. Each candidate
line has the form `<file> <line> - <signature>`, with two leading spaces from
the locale template.

## Emitters

- `Sema.resolveOverloadCall`: the callee is a bare global name with more than
  one overload, at least two candidates share the minimum total
  `conversionCost`, and no single candidate has a strictly lower cost.

Ties include candidates with different parameter orders but the same total
cost. The candidate list contains only the tied minimum-cost overloads, not
every overload.

## Triggers

<a id="TRG-errAmbiguousCall-crossed-mutable-parameters"></a>
### TRG-errAmbiguousCall-crossed-mutable-parameters

<!-- expect-errors: errAmbiguousCall -->
```kovy
int f(int mut a, int b):
  return a + b
int f(int a, int mut b):
  return a + b
int mut x = 1
int mut y = 2
int z = f(x, y)
```

With two mutable arguments, both overloads match:

- `(mut int, int)` costs 1 to drop mutability on the first argument;
- `(int, mut int)` costs 1 to drop mutability on the second argument.

Both total 1, so the call is ambiguous. This is the only known source trigger
in the current compiler.

<a id="TRG-errAmbiguousCall-mixed-mutable-tie"></a>
### TRG-errAmbiguousCall-mixed-mutable-tie

<!-- expect-errors: errAmbiguousCall -->
```kovy
int f(int mut a, bool b):
  return a
int f(int a, bool mut b):
  return a
int mut x = 1
bool mut y = true
int z = f(x, y)
```

Each overload drops mutability on exactly one argument, so both totals are 1.
This shows that ties are not limited to two parameters of the same type.

## Near misses

- If one candidate has a strictly lower total cost, it is selected and the
  call is accepted.
- If no candidate matches, the result is `ERR-errNoMatchingOverload`.
- A single global overload never enters this path; it uses
  `ERR-errWrongArity` or `ERR-errArgMismatch`.
- An argument whose own visit returns `typeError` aborts resolution before any
  ambiguity check.
- A bare overloaded function name used **without** a call is
  `ERR-errAmbiguousFunctionReference`.

## Cascades

The call returns `typeError`, so an enclosing declaration does not add
`errDoesNotFit`. All arguments have already been visited once, so their own
errors can precede this diagnostic. The tied overload list is built from the
recorded declarations and can include forwards; candidate file paths come from
the shared `FileTracker`.

## Tests

- Documentation reproducers: above
- `tests/tFunc.nim`: overload selection with a unique cheapest candidate

## Related

- [SEM-OVL-RESOLUTION](../language/overloads.md#SEM-OVL-RESOLUTION)
- [SEM-TYPE-CONVERSION-COST](../language/types.md#SEM-TYPE-CONVERSION-COST)
- [ERR-errNoMatchingOverload](errNoMatchingOverload.md#ERR-errNoMatchingOverload)
- [ERR-errAmbiguousFunctionReference](errAmbiguousFunctionReference.md#ERR-errAmbiguousFunctionReference)