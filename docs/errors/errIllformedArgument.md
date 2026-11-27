# ERR-errIllformedArgument

<!-- doc-id: ERR-errIllformedArgument -->
<!-- kind: errIllformedArgument -->
<!-- status: declared-not-emitted -->
<!-- phase: none -->

<a id="ERR-errIllformedArgument"></a>
## Status

`declared-not-emitted`.

The enum value and locale entry exist, but no code in `src/` constructs this
error. There is no source program that reaches it in the current compiler.

## Message

Locale key: `errIllformedArgument`.

```text
The argument must be a valid symbol declaration, not a function.
```

No placeholders and no addinfo.

## Emitters

None. Searching `src/` for `errIllformedArgument` finds only:

- the enum declaration in `src/errors.nim`;
- the locale object in `src/error_locales/en.json`.

No lexer, parser, sema, nimgen, or driver code calls `newError` with this
kind.

## Triggers

None are possible in the current implementation. This page deliberately has
no `TRG-*` section; a fabricated reproducer would not be executable.

## Near misses

Conditions that might look related produce other errors:

- A function value passed where a non-function is expected usually produces a
  type or argument mismatch.
- A malformed parameter is a parser error such as `ERR-errSyntax`.
- A duplicate function name is `ERR-errFuncRedefinition`.

## Cascades

None, because the error is never added.

## Maintenance

If an emitter is added:

1. Change the status to `emitted`.
2. Add the exact emitter location.
3. Add at least one `TRG-*` reproducer with an `expect-errors` marker.
4. Update `docs/errors/index.md` and `docs/_meta/coverage.md`.

## Related

- [KOVY-ERRORS-INDEX](index.md#KOVY-ERRORS-INDEX)
- [INT-ERROR-STATUS](../internals/error-system.md#INT-ERROR-STATUS)
- [ERR-errSyntax](errSyntax.md#ERR-errSyntax)
- [ERR-errFuncRedefinition](errFuncRedefinition.md#ERR-errFuncRedefinition)