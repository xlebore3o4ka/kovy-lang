# Error catalogue

<!-- doc-id: KOVY-ERRORS-INDEX -->
<!-- status: current -->

<a id="KOVY-ERRORS-INDEX"></a>
Every currently declared `ErrorKind` has exactly one page in this directory.
The enum is `src/errors.nim`; messages and addinfo are in
`src/error_locales/en.json`. This index is the only global error table.

## How to read an error page

Each page records:

- the exact enum value and locale key;
- the compilation phase that can emit it;
- the exact message and addinfo, with placeholder indexes;
- every source emitter branch;
- one or more `TRG-*` reproducers with the exact `ErrorKind` sequence;
- near misses that produce no error or a different error;
- cascades and related diagnostics.

A reproducer's `expect-errors` marker means the snippet was run through lexer,
parser, sema, `finalize`, and nimgen when the earlier stages were clean. `OK`
means no error in any stage. Multiple kinds are listed in emission order.

## Status vocabulary

| Status | Meaning |
|---|---|
| `emitted` | a reachable source program reaches at least one emitter |
| `guarded` | an emitter exists but no source trigger is known |
| `declared-not-emitted` | no code in `src/` adds this kind |

## All error kinds

<a id="ERR-INDEX-TABLE"></a>
| `ErrorKind` | Phase | Status | Page |
|---|---|---|---|
| `errUnknownCharacter` | lexer | emitted | [ERR-errUnknownCharacter](errUnknownCharacter.md#ERR-errUnknownCharacter) |
| `errSyntax` | parser | emitted | [ERR-errSyntax](errSyntax.md#ERR-errSyntax) |
| `errTypeSyntax` | parser | emitted | [ERR-errTypeSyntax](errTypeSyntax.md#ERR-errTypeSyntax) |
| `errUnknownSymbol` | sema | emitted | [ERR-errUnknownSymbol](errUnknownSymbol.md#ERR-errUnknownSymbol) |
| `errIndent` | lexer, parser | emitted | [ERR-errIndent](errIndent.md#ERR-errIndent) |
| `errExpressionExpected` | parser | emitted | [ERR-errExpressionExpected](errExpressionExpected.md#ERR-errExpressionExpected) |
| `errStatementExpected` | parser | emitted | [ERR-errStatementExpected](errStatementExpected.md#ERR-errStatementExpected) |
| `errDoesNotFit` | sema | emitted | [ERR-errDoesNotFit](errDoesNotFit.md#ERR-errDoesNotFit) |
| `errBinaryMismatch` | sema | emitted | [ERR-errBinaryMismatch](errBinaryMismatch.md#ERR-errBinaryMismatch) |
| `errUnaryMismatch` | sema | emitted | [ERR-errUnaryMismatch](errUnaryMismatch.md#ERR-errUnaryMismatch) |
| `errRedeclaration` | parser, sema | emitted | [ERR-errRedeclaration](errRedeclaration.md#ERR-errRedeclaration) |
| `errImmutableAssignment` | sema | emitted | [ERR-errImmutableAssignment](errImmutableAssignment.md#ERR-errImmutableAssignment) |
| `errContextScope` | sema | emitted | [ERR-errContextScope](errContextScope.md#ERR-errContextScope) |
| `errIllformedArgument` | none | declared-not-emitted | [ERR-errIllformedArgument](errIllformedArgument.md#ERR-errIllformedArgument) |
| `errVoidReturnValue` | sema | emitted | [ERR-errVoidReturnValue](errVoidReturnValue.md#ERR-errVoidReturnValue) |
| `errReturnValueExpected` | sema | emitted | [ERR-errReturnValueExpected](errReturnValueExpected.md#ERR-errReturnValueExpected) |
| `errNotCallable` | sema | emitted | [ERR-errNotCallable](errNotCallable.md#ERR-errNotCallable) |
| `errWrongArity` | sema | emitted | [ERR-errWrongArity](errWrongArity.md#ERR-errWrongArity) |
| `errArgMismatch` | sema | emitted | [ERR-errArgMismatch](errArgMismatch.md#ERR-errArgMismatch) |
| `errReturnDanglingMutable` | sema | emitted | [ERR-errReturnDanglingMutable](errReturnDanglingMutable.md#ERR-errReturnDanglingMutable) |
| `errImmutableReturn` | sema | emitted | [ERR-errImmutableReturn](errImmutableReturn.md#ERR-errImmutableReturn) |
| `errNotAllPathsReturn` | sema | emitted | [ERR-errNotAllPathsReturn](errNotAllPathsReturn.md#ERR-errNotAllPathsReturn) |
| `errUnreachableCode` | sema | emitted | [ERR-errUnreachableCode](errUnreachableCode.md#ERR-errUnreachableCode) |
| `errForwardOutsideGlobal` | sema | emitted | [ERR-errForwardOutsideGlobal](errForwardOutsideGlobal.md#ERR-errForwardOutsideGlobal) |
| `errFuncSignatureMismatch` | sema | emitted | [ERR-errFuncSignatureMismatch](errFuncSignatureMismatch.md#ERR-errFuncSignatureMismatch) |
| `errFuncRedefinition` | sema | emitted | [ERR-errFuncRedefinition](errFuncRedefinition.md#ERR-errFuncRedefinition) |
| `errUnresolvedForward` | sema/finalize | emitted | [ERR-errUnresolvedForward](errUnresolvedForward.md#ERR-errUnresolvedForward) |
| `errOverloadByReturnType` | sema | emitted | [ERR-errOverloadByReturnType](errOverloadByReturnType.md#ERR-errOverloadByReturnType) |
| `errAmbiguousCall` | sema | emitted | [ERR-errAmbiguousCall](errAmbiguousCall.md#ERR-errAmbiguousCall) |
| `errNoMatchingOverload` | sema | emitted | [ERR-errNoMatchingOverload](errNoMatchingOverload.md#ERR-errNoMatchingOverload) |
| `errAmbiguousFunctionReference` | sema | emitted | [ERR-errAmbiguousFunctionReference](errAmbiguousFunctionReference.md#ERR-errAmbiguousFunctionReference) |
| `errEmptyFunctionBody` | parser | emitted | [ERR-errEmptyFunctionBody](errEmptyFunctionBody.md#ERR-errEmptyFunctionBody) |
| `errDefaultForbidden` | sema | emitted | [ERR-errDefaultForbidden](errDefaultForbidden.md#ERR-errDefaultForbidden) |
| `errAllocCount` | sema | emitted | [ERR-errAllocCount](errAllocCount.md#ERR-errAllocCount) |
| `errAllocVoid` | sema | emitted | [ERR-errAllocVoid](errAllocVoid.md#ERR-errAllocVoid) |
| `errAllocInLoop` | sema | emitted | [ERR-errAllocInLoop](errAllocInLoop.md#ERR-errAllocInLoop) |
| `errArrayTypeRequired` | sema | emitted | [ERR-errArrayTypeRequired](errArrayTypeRequired.md#ERR-errArrayTypeRequired) |
| `errDerefNonPointer` | sema | emitted | [ERR-errDerefNonPointer](errDerefNonPointer.md#ERR-errDerefNonPointer) |
| `errAddrFromImmutable` | sema | emitted | [ERR-errAddrFromImmutable](errAddrFromImmutable.md#ERR-errAddrFromImmutable) |
| `errNonConcreteType` | nimgen | emitted | [ERR-errNonConcreteType](errNonConcreteType.md#ERR-errNonConcreteType) |

## Related indexes

- [Error reference table](../reference/error-index.md#REF-ERROR-INDEX)
- [Coverage matrix](../_meta/coverage.md#COVERAGE-ERRORS)
- [Error system internals](../internals/error-system.md#INT-ERROR-SYSTEM)
- [Verification protocol](../_meta/verification.md#KOVY-VERIFICATION)