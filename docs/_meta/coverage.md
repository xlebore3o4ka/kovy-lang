# Coverage matrix

<a id="KOVY-COVERAGE"></a>
This matrix is the completeness contract for the documentation. Every row
must have a documentation destination. Rows are added, not rewritten, when
the language grows.

## Lexical tokens

<a id="COVERAGE-TOKENS"></a>
| Token family | Members | Reference |
|---|---|---|
| structural | `tkInvalid`, `tkEOF`, `tkEOS`, `tkIndent`, `tkDedent` | [tokens](../reference/tokens.md#REF-TOKENS), [indentation](../language/indentation.md#KOVY-INDENTATION) |
| literals and names | `tkNumber`, `tkIdent` | [lexical](../language/lexical.md#SYN-LEX-IDENTIFIER), [lexical](../language/lexical.md#SYN-LEX-NUMBER) |
| arithmetic | `tkPlus`, `tkMinus`, `tkStar`, `tkSlash` | [operators](../reference/operators.md#REF-OPERATORS), [expressions](../language/expressions.md#SYN-EXPR-BINARY) |
| grouping and calls | `tkLParen`, `tkRParen`, `tkLBracket`, `tkRBracket`, `tkComma` | [grammar](../language/grammar.md#KOVY-GRAMMAR) |
| assignment and punctuation | `tkEquals`, `tkColon`, `tkHash`, `tkBang` | [operators](../reference/operators.md#REF-OPERATORS) |
| comparison | `tkGt`, `tkLt`, `tkGe`, `tkLe`, `tkEq`, `tkNe` | [precedence](../reference/precedence.md#REF-PRECEDENCE) |
| type keywords | `tkInt`, `tkBool`, `tkVoid` | [types](../language/types.md#KOVY-TYPES) |
| boolean keywords | `tkTrue`, `tkFalse`, `tkNot`, `tkAnd`, `tkOr` | [expressions](../language/expressions.md#SYN-EXPR-LITERAL) |
| declaration keywords | `tkMut`, `tkAlloc`, `tkOf`, `tkAddr` | [declarations](../language/declarations.md#KOVY-DECLARATIONS), [pointers](../language/pointers.md#KOVY-POINTERS) |
| control keywords | `tkIf`, `tkElif`, `tkElse`, `tkWhile`, `tkBreak`, `tkContinue`, `tkReturn` | [statements](../language/statements.md#KOVY-STATEMENTS) |

## Parser productions

<a id="COVERAGE-PARSER"></a>
| Procedure | Syntax destination |
|---|---|
| `parse` / `parseStmts` | [program and separators](../language/grammar.md#SYN-GRAMMAR-PROGRAM) |
| `parseStmt` | [statements](../language/statements.md#SYN-STMT-EXPR) |
| `parseBlock` | [blocks](../language/grammar.md#SYN-GRAMMAR-BLOCK) |
| `parseDecl` | [declarations](../language/declarations.md#SYN-DECL-GROUP) |
| `parseFuncDecl` | [functions](../language/functions.md#SYN-FUNC-DECL) |
| `parseType` | [type syntax](../language/types.md#SYN-TYPE-SYNTAX) |
| `parseAlloc` | [alloc](../language/pointers.md#SYN-ALLOC) |
| `parseArrayLit` | [array literal](../language/arrays.md#SYN-ARRAY-LITERAL) |
| `parsePrimary` | [primary expressions](../language/expressions.md#SYN-EXPR-PRIMARY) |
| `parsePostfix` | [calls](../language/expressions.md#SYN-EXPR-CALL) |
| `parseUnary` | [unary expressions](../language/expressions.md#SYN-EXPR-UNARY) |
| `parseMulDiv` | [precedence](../reference/precedence.md#REF-PRECEDENCE) |
| `parseAddSub` | [precedence](../reference/precedence.md#REF-PRECEDENCE) |
| `parseCmp` | [precedence](../reference/precedence.md#REF-PRECEDENCE) |
| `parseAnd` / `parseOr` | [precedence](../reference/precedence.md#REF-PRECEDENCE) |
| `parseAssignment` | [assignment](../language/expressions.md#SYN-EXPR-ASSIGN) |
| `parseExpr` | [expressions](../language/expressions.md#SYN-EXPR-BINARY) |
| `parseBranch` | [if/elif/else](../language/statements.md#SYN-STMT-IF) |
| `parseWhile` | [while](../language/statements.md#SYN-STMT-WHILE) |
| `parseBreak` / `parseContinue` | [loop control](../language/statements.md#SYN-STMT-BREAK) |
| `parseReturn` | [return](../language/statements.md#SYN-STMT-RETURN) |

## AST nodes

<a id="COVERAGE-AST"></a>
| `NodeKind` | Documentation |
|---|---|
| `nkInvalid` | [AST](../internals/ast.md#INT-AST-NODEKINDS) |
| `nkNumber`, `nkBool` | [expressions](../language/expressions.md#SYN-EXPR-LITERAL) |
| `nkBinary`, `nkUnary` | [expressions](../language/expressions.md#SYN-EXPR-BINARY) |
| `nkBlock` | [grammar](../language/grammar.md#SYN-GRAMMAR-BLOCK) |
| `nkSymbol` | [expressions](../language/expressions.md#SYN-EXPR-SYMBOL) |
| `nkExprStmt` | [statements](../language/statements.md#SYN-STMT-EXPR) |
| `nkDecl` | [declarations](../language/declarations.md#SYN-DECL-GROUP) |
| `nkBranch` | [statements](../language/statements.md#SYN-STMT-IF) |
| `nkWhile` | [statements](../language/statements.md#SYN-STMT-WHILE) |
| `nkBreak`, `nkContinue` | [statements](../language/statements.md#SYN-STMT-BREAK) |
| `nkFuncDecl` | [functions](../language/functions.md#SYN-FUNC-DECL) |
| `nkReturn` | [statements](../language/statements.md#SYN-STMT-RETURN) |
| `nkCall` | [expressions](../language/expressions.md#SYN-EXPR-CALL) |
| `nkAlloc` | [pointers](../language/pointers.md#SYN-ALLOC) |
| `nkArrayLit` | [arrays](../language/arrays.md#SYN-ARRAY-LITERAL) |

## Type kinds

<a id="COVERAGE-TYPES"></a>
| `TypeKind` | User-visible | Documentation |
|---|---|---|
| `typeNumberLit` | no | [type model](../internals/types.md#INT-TYPES-KINDS) |
| `typeBoolLit` | no | [type model](../internals/types.md#INT-TYPES-KINDS) |
| `typeInt` | `int` | [types](../language/types.md#SEM-TYPE-INT) |
| `typeBool` | `bool` | [types](../language/types.md#SEM-TYPE-BOOL) |
| `typeVoid` | `void` | [types](../language/types.md#SEM-TYPE-VOID) |
| `typeError` | no | [type model](../internals/types.md#INT-TYPES-KINDS) |
| `typeMutable` | `mut` wrapper | [mutability](../language/mutability.md#KOVY-MUTABILITY) |
| `typePtr` | `T*` | [pointers](../language/pointers.md#SYN-PTR-TYPE) |
| `typeFunc` | `T(args)` | [types](../language/types.md#SEM-TYPE-FUNC) |

## Sema areas

<a id="COVERAGE-SEMA"></a>
| Area | Documentation |
|---|---|
| symbol tables and scopes | [scopes](../language/scopes.md#KOVY-SCOPES) |
| declaration checking | [declarations](../language/declarations.md#SEM-DECL-RULES) |
| `fits`, `sameType`, conversion cost | [types](../language/types.md#SEM-TYPE-FITS) |
| binary and unary typing | [expressions](../language/expressions.md#SYN-EXPR-BINARY) |
| assignment and mutability | [mutability](../language/mutability.md#SEM-MUT-WRITE) |
| calls and function values | [functions](../language/functions.md#SEM-FUNC-CALL) |
| overload resolution | [overloads](../language/overloads.md#SEM-OVL-RESOLUTION) |
| alloc, dereference, addr | [pointers](../language/pointers.md#SEM-PTR-RULES) |
| array literals | [arrays](../language/arrays.md#SEM-ARR-RULES) |
| loop contexts | [scopes](../language/scopes.md#SEM-SCOPE-CONTEXT) |
| return analysis | [control flow](../language/control-flow.md#SEM-FLOW-RETURN-PATHS) |
| unreachable code | [control flow](../language/control-flow.md#SEM-FLOW-UNREACHABLE) |
| forward declarations | [functions](../language/functions.md#SEM-FUNC-FORWARD) |

## Nimgen and runtime

<a id="COVERAGE-NIMGEN"></a>
| Area | Documentation |
|---|---|
| name encoding and mangling | [nimgen](../internals/nimgen.md#INT-NIMGEN-NAMES) |
| declaration emission | [nimgen](../internals/nimgen.md#INT-NIMGEN-EMIT) |
| calls and overloads | [nimgen](../internals/nimgen.md#INT-NIMGEN-CALLS) |
| assignment through calls | [nimgen](../internals/nimgen.md#INT-NIMGEN-ASSIGN) |
| alloc and array literals | [nimgen](../internals/nimgen.md#INT-NIMGEN-MEMORY) |
| pointer arithmetic helpers | [runtime](../internals/runtime.md#INT-RUNTIME-PTR-ARITH) |
| stack allocation helpers | [runtime](../internals/runtime.md#INT-RUNTIME-ALLOCA) |
| array-literal helper | [runtime](../internals/runtime.md#INT-RUNTIME-ARRAYLIT) |
| `errNonConcreteType` | [nimgen](../internals/nimgen.md#INT-NIMGEN-NONCONCRETE) |

## Error kinds

<a id="COVERAGE-ERRORS"></a>
All current `ErrorKind` values must have exactly one page. Status meanings:

- `emitted`: at least one reachable emitter branch is documented.
- `guarded`: the branch exists, but no source program is known to reach it
  without an earlier error.
- `declared-not-emitted`: the enum value has no emitter in `src/`.

| `ErrorKind` | Phase | Status | Page |
|---|---|---|---|
| `errUnknownCharacter` | lexer | emitted | [ERR-errUnknownCharacter](../errors/errUnknownCharacter.md#ERR-errUnknownCharacter) |
| `errSyntax` | parser | emitted | [ERR-errSyntax](../errors/errSyntax.md#ERR-errSyntax) |
| `errTypeSyntax` | parser | emitted | [ERR-errTypeSyntax](../errors/errTypeSyntax.md#ERR-errTypeSyntax) |
| `errUnknownSymbol` | sema | emitted | [ERR-errUnknownSymbol](../errors/errUnknownSymbol.md#ERR-errUnknownSymbol) |
| `errIndent` | lexer/parser | emitted | [ERR-errIndent](../errors/errIndent.md#ERR-errIndent) |
| `errExpressionExpected` | parser | emitted | [ERR-errExpressionExpected](../errors/errExpressionExpected.md#ERR-errExpressionExpected) |
| `errStatementExpected` | parser | emitted | [ERR-errStatementExpected](../errors/errStatementExpected.md#ERR-errStatementExpected) |
| `errDoesNotFit` | sema | emitted | [ERR-errDoesNotFit](../errors/errDoesNotFit.md#ERR-errDoesNotFit) |
| `errBinaryMismatch` | sema | emitted | [ERR-errBinaryMismatch](../errors/errBinaryMismatch.md#ERR-errBinaryMismatch) |
| `errUnaryMismatch` | sema | emitted | [ERR-errUnaryMismatch](../errors/errUnaryMismatch.md#ERR-errUnaryMismatch) |
| `errRedeclaration` | parser/sema | emitted | [ERR-errRedeclaration](../errors/errRedeclaration.md#ERR-errRedeclaration) |
| `errImmutableAssignment` | sema | emitted | [ERR-errImmutableAssignment](../errors/errImmutableAssignment.md#ERR-errImmutableAssignment) |
| `errContextScope` | sema | emitted | [ERR-errContextScope](../errors/errContextScope.md#ERR-errContextScope) |
| `errIllformedArgument` | none | declared-not-emitted | [ERR-errIllformedArgument](../errors/errIllformedArgument.md#ERR-errIllformedArgument) |
| `errVoidReturnValue` | sema | emitted | [ERR-errVoidReturnValue](../errors/errVoidReturnValue.md#ERR-errVoidReturnValue) |
| `errReturnValueExpected` | sema | emitted | [ERR-errReturnValueExpected](../errors/errReturnValueExpected.md#ERR-errReturnValueExpected) |
| `errNotCallable` | sema | emitted | [ERR-errNotCallable](../errors/errNotCallable.md#ERR-errNotCallable) |
| `errWrongArity` | sema | emitted | [ERR-errWrongArity](../errors/errWrongArity.md#ERR-errWrongArity) |
| `errArgMismatch` | sema | emitted | [ERR-errArgMismatch](../errors/errArgMismatch.md#ERR-errArgMismatch) |
| `errReturnDanglingMutable` | sema | emitted | [ERR-errReturnDanglingMutable](../errors/errReturnDanglingMutable.md#ERR-errReturnDanglingMutable) |
| `errImmutableReturn` | sema | emitted | [ERR-errImmutableReturn](../errors/errImmutableReturn.md#ERR-errImmutableReturn) |
| `errNotAllPathsReturn` | sema | emitted | [ERR-errNotAllPathsReturn](../errors/errNotAllPathsReturn.md#ERR-errNotAllPathsReturn) |
| `errUnreachableCode` | sema | emitted | [ERR-errUnreachableCode](../errors/errUnreachableCode.md#ERR-errUnreachableCode) |
| `errForwardOutsideGlobal` | sema | emitted | [ERR-errForwardOutsideGlobal](../errors/errForwardOutsideGlobal.md#ERR-errForwardOutsideGlobal) |
| `errFuncSignatureMismatch` | sema | emitted | [ERR-errFuncSignatureMismatch](../errors/errFuncSignatureMismatch.md#ERR-errFuncSignatureMismatch) |
| `errFuncRedefinition` | sema | emitted | [ERR-errFuncRedefinition](../errors/errFuncRedefinition.md#ERR-errFuncRedefinition) |
| `errUnresolvedForward` | sema | emitted | [ERR-errUnresolvedForward](../errors/errUnresolvedForward.md#ERR-errUnresolvedForward) |
| `errOverloadByReturnType` | sema | emitted | [ERR-errOverloadByReturnType](../errors/errOverloadByReturnType.md#ERR-errOverloadByReturnType) |
| `errAmbiguousCall` | sema | emitted | [ERR-errAmbiguousCall](../errors/errAmbiguousCall.md#ERR-errAmbiguousCall) |
| `errNoMatchingOverload` | sema | emitted | [ERR-errNoMatchingOverload](../errors/errNoMatchingOverload.md#ERR-errNoMatchingOverload) |
| `errAmbiguousFunctionReference` | sema | emitted | [ERR-errAmbiguousFunctionReference](../errors/errAmbiguousFunctionReference.md#ERR-errAmbiguousFunctionReference) |
| `errEmptyFunctionBody` | parser | emitted | [ERR-errEmptyFunctionBody](../errors/errEmptyFunctionBody.md#ERR-errEmptyFunctionBody) |
| `errDefaultForbidden` | sema | emitted | [ERR-errDefaultForbidden](../errors/errDefaultForbidden.md#ERR-errDefaultForbidden) |
| `errAllocCount` | sema | emitted | [ERR-errAllocCount](../errors/errAllocCount.md#ERR-errAllocCount) |
| `errAllocVoid` | sema | emitted | [ERR-errAllocVoid](../errors/errAllocVoid.md#ERR-errAllocVoid) |
| `errAllocInLoop` | sema | emitted | [ERR-errAllocInLoop](../errors/errAllocInLoop.md#ERR-errAllocInLoop) |
| `errArrayTypeRequired` | sema | emitted | [ERR-errArrayTypeRequired](../errors/errArrayTypeRequired.md#ERR-errArrayTypeRequired) |
| `errDerefNonPointer` | sema | emitted | [ERR-errDerefNonPointer](../errors/errDerefNonPointer.md#ERR-errDerefNonPointer) |
| `errAddrFromImmutable` | sema | emitted | [ERR-errAddrFromImmutable](../errors/errAddrFromImmutable.md#ERR-errAddrFromImmutable) |
| `errNonConcreteType` | nimgen | emitted | [ERR-errNonConcreteType](../errors/errNonConcreteType.md#ERR-errNonConcreteType) |