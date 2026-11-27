# Error index

<!-- doc-id: REF-ERROR-INDEX -->
<!-- status: current -->

<a id="REF-ERROR-INDEX"></a>
This is the complete cross-reference for the 40 current `ErrorKind` values.
Each kind has exactly one page under `docs/errors/` and one row in
[the error catalogue](../errors/index.md#KOVY-ERRORS-INDEX). The authoritative
enum is `src/errors.nim`; exact message text comes from
`src/error_locales/en.json`.

`TRG` counts the published trigger sections on the page, not the number of
emitter branches. A kind marked `declared-not-emitted` has an enum value and a
locale entry but no call to `newError` anywhere in `src/`.

<a id="REF-ERROR-INDEX-TABLE"></a>
## All error kinds

| `ErrorKind` | Phase | Status | `TRG` | Message | Page |
|---|---|---|---|---|---|
| `errAddrFromImmutable` | sema | emitted | 6 | `Cannot take the address of an immutable expression` | [page](../errors/errAddrFromImmutable.md#ERR-errAddrFromImmutable) |
| `errAllocCount` | sema | emitted | 4 | `alloc expects an integer element count, got @c0` | [page](../errors/errAllocCount.md#ERR-errAllocCount) |
| `errAllocInLoop` | sema | emitted | 5 | `Cannot allocate memory inside a loop` | [page](../errors/errAllocInLoop.md#ERR-errAllocInLoop) |
| `errAllocVoid` | sema | emitted | 4 | `Cannot allocate elements of type void` | [page](../errors/errAllocVoid.md#ERR-errAllocVoid) |
| `errAmbiguousCall` | sema | emitted | 2 | `Ambiguous call to @q0 with arguments (@1)` | [page](../errors/errAmbiguousCall.md#ERR-errAmbiguousCall) |
| `errAmbiguousFunctionReference` | sema | emitted | 4 | `Ambiguous reference to function @q0` | [page](../errors/errAmbiguousFunctionReference.md#ERR-errAmbiguousFunctionReference) |
| `errArgMismatch` | sema | emitted | 4 | `Argument @c0 has type @c1, expected @c2` | [page](../errors/errArgMismatch.md#ERR-errArgMismatch) |
| `errArrayTypeRequired` | sema | emitted | 4 | `Cannot infer the element type of an empty array literal` | [page](../errors/errArrayTypeRequired.md#ERR-errArrayTypeRequired) |
| `errBinaryMismatch` | sema | emitted | 4 | `Binary type mismatch for @0: @c1` | [page](../errors/errBinaryMismatch.md#ERR-errBinaryMismatch) |
| `errContextScope` | sema | emitted | 5 | `@q0 statement outside @q1 context` | [page](../errors/errContextScope.md#ERR-errContextScope) |
| `errDefaultForbidden` | sema | emitted | 5 | `Parameter @q0 cannot have a default value` | [page](../errors/errDefaultForbidden.md#ERR-errDefaultForbidden) |
| `errDerefNonPointer` | sema | emitted | 5 | `Cannot dereference a non-pointer value of type @c0` | [page](../errors/errDerefNonPointer.md#ERR-errDerefNonPointer) |
| `errDoesNotFit` | sema | emitted | 7 | `Type @c0 does not fit into type @c1` | [page](../errors/errDoesNotFit.md#ERR-errDoesNotFit) |
| `errEmptyFunctionBody` | parser | emitted | 3 | `Function body cannot be empty` | [page](../errors/errEmptyFunctionBody.md#ERR-errEmptyFunctionBody) |
| `errExpressionExpected` | parser | emitted | 5 | `Expected expression after @c1, got @0` | [page](../errors/errExpressionExpected.md#ERR-errExpressionExpected) |
| `errForwardOutsideGlobal` | sema | emitted | 3 | `Forward declaration of @q0 is only allowed at global scope` | [page](../errors/errForwardOutsideGlobal.md#ERR-errForwardOutsideGlobal) |
| `errFuncRedefinition` | sema | emitted | 6 | `Function @q0 is already declared` | [page](../errors/errFuncRedefinition.md#ERR-errFuncRedefinition) |
| `errFuncSignatureMismatch` | sema | emitted | 3 | `Definition of @q0 does not match its forward declaration` | [page](../errors/errFuncSignatureMismatch.md#ERR-errFuncSignatureMismatch) |
| `errIllformedArgument` | none | declared-not-emitted | 0 | `The argument must be a valid symbol declaration, not a function.` | [page](../errors/errIllformedArgument.md#ERR-errIllformedArgument) |
| `errImmutableAssignment` | sema | emitted | 7 | `Cannot assign a value to an immutable expression` | [page](../errors/errImmutableAssignment.md#ERR-errImmutableAssignment) |
| `errImmutableReturn` | sema | emitted | 3 | `Cannot return an immutable value from a mutable function` | [page](../errors/errImmutableReturn.md#ERR-errImmutableReturn) |
| `errIndent` | lexer, parser | emitted | 4 | `Invalid indentation` | [page](../errors/errIndent.md#ERR-errIndent) |
| `errNoMatchingOverload` | sema | emitted | 4 | `No overload of @q0 matches arguments (@1)` | [page](../errors/errNoMatchingOverload.md#ERR-errNoMatchingOverload) |
| `errNonConcreteType` | nimgen | emitted | 6 | `Type @c0 is not concrete` | [page](../errors/errNonConcreteType.md#ERR-errNonConcreteType) |
| `errNotAllPathsReturn` | sema | emitted | 4 | `Not all control paths return a value` | [page](../errors/errNotAllPathsReturn.md#ERR-errNotAllPathsReturn) |
| `errNotCallable` | sema | emitted | 4 | `Expression @c0 is not callable` | [page](../errors/errNotCallable.md#ERR-errNotCallable) |
| `errOverloadByReturnType` | sema | emitted | 4 | `Cannot overload @q0 by return type only` | [page](../errors/errOverloadByReturnType.md#ERR-errOverloadByReturnType) |
| `errRedeclaration` | parser, sema | emitted | 7 | `Redeclaring the @q0 symbol` | [page](../errors/errRedeclaration.md#ERR-errRedeclaration) |
| `errReturnDanglingMutable` | sema | emitted | 3 | `Cannot return mutable symbol @q0: its lifetime does not exceed the function scope` | [page](../errors/errReturnDanglingMutable.md#ERR-errReturnDanglingMutable) |
| `errReturnValueExpected` | sema | emitted | 3 | `Expected return value of type @c0` | [page](../errors/errReturnValueExpected.md#ERR-errReturnValueExpected) |
| `errStatementExpected` | parser | emitted | 4 | `@0 is not a statement` | [page](../errors/errStatementExpected.md#ERR-errStatementExpected) |
| `errSyntax` | parser | emitted | 8 | `Syntax error, expected @0, got @1` | [page](../errors/errSyntax.md#ERR-errSyntax) |
| `errTypeSyntax` | parser | emitted | 4 | `Syntax error for a type` | [page](../errors/errTypeSyntax.md#ERR-errTypeSyntax) |
| `errUnaryMismatch` | sema | emitted | 4 | `Unary type mismatch for @0 with type @1` | [page](../errors/errUnaryMismatch.md#ERR-errUnaryMismatch) |
| `errUnknownCharacter` | lexer | emitted | 2 | `Unknown character: @q0` | [page](../errors/errUnknownCharacter.md#ERR-errUnknownCharacter) |
| `errUnknownSymbol` | sema | emitted | 5 | `Unknown symbol: @q0` | [page](../errors/errUnknownSymbol.md#ERR-errUnknownSymbol) |
| `errUnreachableCode` | sema | emitted | 6 | `Unreachable code from line @0 to line @1` | [page](../errors/errUnreachableCode.md#ERR-errUnreachableCode) |
| `errUnresolvedForward` | sema/finalize | emitted | 6 | `Forward-declared function @q0 has no definition` | [page](../errors/errUnresolvedForward.md#ERR-errUnresolvedForward) |
| `errVoidReturnValue` | sema | emitted | 2 | `Cannot return a value from a void function` | [page](../errors/errVoidReturnValue.md#ERR-errVoidReturnValue) |
| `errWrongArity` | sema | emitted | 4 | `Wrong number of arguments: expected @n1, got @n0` | [page](../errors/errWrongArity.md#ERR-errWrongArity) |

<a id="REF-ERROR-INDEX-PHASES"></a>
## By phase

| Phase | Kinds |
|---|---|
| lexer | `errUnknownCharacter` |
| lexer, parser | `errIndent` |
| parser | `errSyntax`, `errTypeSyntax`, `errExpressionExpected`, `errStatementExpected`, `errRedeclaration`, `errEmptyFunctionBody` |
| sema | the remaining 31 emitted sema kinds |
| sema/finalize | `errUnresolvedForward` |
| nimgen | `errNonConcreteType` |
| none | `errIllformedArgument` |

`errRedeclaration` is listed as parser and sema because the parser detects a
duplicate name inside one declaration group, while sema detects all other
in-scope duplicates. `errIndent` can be produced by the lexer's indentation
machine or by the parser's block expectations.

<a id="REF-ERROR-INDEX-INVARIANTS"></a>
## Invariants

- Exactly one page exists per enum value.
- Exactly one row exists here per enum value.
- Exactly one row exists in `_meta/coverage.md` per enum value.
- `errIllformedArgument` is the only `declared-not-emitted` kind.
- No kind is currently `guarded`: `errAmbiguousCall` has a reproducible
  trigger and is `emitted`.
- Error ordering within one program is source order for lex/parse/sema
  diagnostics; `finalize` diagnostics (`errUnresolvedForward`) come last;
  nimgen diagnostics appear only when all earlier phases are clean.

## Related

- [Error catalogue](../errors/index.md#KOVY-ERRORS-INDEX)
- [Coverage matrix](../_meta/coverage.md#COVERAGE-ERRORS)
- [Error system](../internals/error-system.md#INT-ERROR-SYSTEM)
- [Verification protocol](../_meta/verification.md#KOVY-VERIFICATION)