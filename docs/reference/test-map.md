# Test map

<!-- doc-id: REF-TEST-MAP -->
<!-- status: current -->

<a id="REF-TEST-MAP"></a>
Every test in `tests/` is listed here with the documentation it exercises.
Tests are the regression contract for the documented behavior. A test marked
with an error kind asserts that the kind is present; the error page's `TRG-*`
sections provide the complete, ordered reproducer.

Run the suite with:

```text
nimble test --hints:off --warnings:off
```

<a id="REF-TEST-MAP-FUNC"></a>
## `tests/tFunc.nim`

| Test | Covers |
|---|---|
| grouped parameters become separate arguments | `SYN-FUNC-PARAMS`, `SEM-FUNC-PARAMS` |
| parameter groups can change type | `SYN-FUNC-PARAMS`, `SEM-FUNC-PARAMS` |
| grouped mutable parameters share mutability | `SYN-FUNC-PARAMS`, `SYN-MUT` |
| void calls are not discarded | `SEM-FUNC-RETURN`, `INT-NIMGEN-CALLS` |
| overloaded void calls are not discarded | `SEM-OVL-RESOLUTION`, `INT-NIMGEN-CALLS` |
| forward declaration and definition match | `SEM-FUNC-FORWARD` |
| unresolved forward declaration is reported | `ERR-errUnresolvedForward` (`TRG-errUnresolvedForward-never-defined`) |
| recursive calls are resolved | `SEM-FUNC-ORDER`, `SEM-FUNC-VALUES` |
| default parameter values are forbidden | `ERR-errDefaultForbidden` (`TRG-errDefaultForbidden-single`) |
| all paths returning through if/else are accepted | `SEM-FLOW-RETURN-PATHS` |
| missing return path is reported | `ERR-errNotAllPathsReturn` (`TRG-errNotAllPathsReturn-missing-else`) |
| while true does not require a return after the loop | `SEM-FLOW-EXITS-LOOP`, `SEM-FLOW-RETURN-PATHS` |
| while true with break still requires a return | `ERR-errNotAllPathsReturn` (`TRG-errNotAllPathsReturn-while-break`) |
| break in a nested loop does not exit the outer loop | `SEM-FLOW-EXITS-LOOP` |
| code after an exhaustive if/else is unreachable | `ERR-errUnreachableCode` (`TRG-errUnreachableCode-after-exhaustive-if`) |
| empty function body is rejected | `ERR-errEmptyFunctionBody` |
| nested functions cannot be overloaded | `ERR-errFuncRedefinition` (`TRG-errFuncRedefinition-nested-overload`) |
| function values can be declared and called | `SEM-FUNC-VALUES`, `SYN-TYPE-SYNTAX` |
| functions can be passed as arguments | `SEM-FUNC-VALUES`, `SEM-FUNC-PARAMS` |
| functions can be returned and called | `SEM-FUNC-VALUES`, `SYN-EXPR-CALL` |
| mutable parameters are preserved in function types | `SEM-FUNC-VALUES`, `SYN-TYPE-SYNTAX` |
| overloaded functions resolve by expected type | `SEM-OVL-REFERENCES` |
| overloaded functions resolve as call arguments | `SEM-OVL-REFERENCES`, `SEM-OVL-RESOLUTION` |
| ambiguous function references are rejected | `ERR-errAmbiguousFunctionReference` (`TRG-errAmbiguousFunctionReference-initializer`) |
| mutable function variables can be reassigned | `SEM-MUT-ASSIGN`, `SEM-FUNC-VALUES` |
| void functions can be stored in function values | `SEM-FUNC-VALUES` |
| function values can return void functions | `SEM-FUNC-VALUES`, `SYN-EXPR-CALL` |

<a id="REF-TEST-MAP-PTR"></a>
## `tests/tPtr.nim`

| Test | Covers |
|---|---|
| pointer syntax | `SYN-PTR-TYPE`, `SEM-TYPE-PTR` |
| pointer suffixes repeat | `SYN-PTR-TYPE`, `SEM-TYPE-PTR` |
| pointer to function type | `SYN-TYPE-SYNTAX`, `SEM-PTR-FUNCTION` |
| sameType compares pointers | `SEM-TYPE-SAME` |
| hash is stable for pointers | `SEM-TYPE-SAME` (internal hash contract) |
| allocates a pointer to the element type | `SYN-ALLOC`, `SEM-PTR-ALLOC-MEMORY`, `INT-RUNTIME-ALLOCA` |
| count expression keeps its precedence | `SYN-ALLOC`, `REF-PRECEDENCE` |
| count multiplication keeps its precedence | `SYN-ALLOC`, `REF-PRECEDENCE` |
| pointer element type | `SYN-ALLOC`, `SEM-PTR-ALLOC-MEMORY` |
| non-number count is rejected | `ERR-errAllocCount` (`TRG-errAllocCount-bool`) |
| alloc of void is rejected | `ERR-errAllocVoid` (`TRG-errAllocVoid-alloc`) |
| alloc inside a loop is rejected | `ERR-errAllocInLoop` (`TRG-errAllocInLoop-alloc`) |
| alloc inside a branch in a loop is rejected | `ERR-errAllocInLoop` (`TRG-errAllocInLoop-branch`) |
| alloc outside a loop is allowed | `SEM-PTR-ALLOC-MEMORY` |
| alloc inside a function declared in a loop is allowed | `ERR-errAllocInLoop` (`TRG-errAllocInLoop-nested-function-allowed`) |
| allocates and fills an int array | `SEM-ARR-MEMORY`, `INT-RUNTIME-ARRAYLIT` |
| uses the explicit element type | `SEM-ARR-INFERENCE`, `SYN-ARRAY-LITERAL` |
| infers bool elements | `SEM-ARR-INFERENCE` |
| empty array literal | `SEM-ARR-INFERENCE`, `INT-RUNTIME-ARRAYLIT` |
| array of function values | `SEM-ARR-FUNCTIONS` |
| mutable pointer allows writing through an element | `SEM-MUT-PTR`, `SEM-MUT-WRITE`, `SEM-ARR-MEMORY` |
| nested array literals | `SEM-ARR-NESTED` |
| mutable pointer variable | `SYN-PTR-DEREF`, `SEM-MUT-PTR` |
| pointer arithmetic operand | `SEM-PTR-ARITHMETIC`, `SYN-PTR-DEREF` |
| double dereference | `SYN-PTR-DEREF`, `SEM-PTR-RULES` |
| dereferencing a non-pointer is rejected | `ERR-errDerefNonPointer` (`TRG-errDerefNonPointer-mutable-scalar`) |
| immutable pointer variable cannot write | `ERR-errImmutableAssignment`, `SEM-MUT-WRITE` |
| immutable pointer variable can read | `SEM-MUT-WRITE` |
| pointer arithmetic keeps write permission from a mutable pointer | `SEM-PTR-ARITHMETIC`, `SEM-MUT-WRITE` |
| pointer arithmetic from an immutable pointer cannot write | `ERR-errImmutableAssignment`, `SEM-PTR-ARITHMETIC` |
| pointer difference is not writable | `ERR-errDerefNonPointer`, `SEM-PTR-ARITHMETIC` |
| addr becomes writable only through a mutable symbol | `SYN-PTR-ADDR`, `SEM-MUT-PTR` |
| immutable symbol holding an address cannot write | `ERR-errImmutableAssignment`, `SEM-PTR-DEREF-GRANT` |
| direct addr dereference cannot write | `ERR-errImmutableAssignment`, `SEM-PTR-DEREF-GRANT` |
| direct alloc dereference cannot write | `ERR-errImmutableAssignment`, `SEM-PTR-DEREF-GRANT` |
| mutable pointer parameter can write | `SEM-FUNC-PARAMS`, `SEM-MUT-WRITE` |
| immutable pointer parameter cannot write | `ERR-errImmutableAssignment`, `SEM-FUNC-PARAMS` |
| mutable pointer return grants write access | `SEM-MUT-RETURN`, `SEM-PTR-DEREF-GRANT` |
| immutable pointer return does not grant write access | `ERR-errImmutableAssignment`, `SEM-MUT-RETURN` |
| addr of a dereference requires a mutable pointer | `ERR-errAddrFromImmutable` (`TRG-errAddrFromImmutable-immutable-deref`) |
| mutable symbol | `SYN-PTR-ADDR` |
| dereference | `SYN-PTR-ADDR`, `SEM-MUT-PTR` |
| mutable function call | `SYN-PTR-ADDR`, `SEM-MUT-RETURN` |
| mutable pointer variable yields pointer to pointer | `SYN-PTR-ADDR`, `SYN-PTR-TYPE` |
| immutable expression is rejected | `ERR-errAddrFromImmutable` (`TRG-errAddrFromImmutable-immutable-variable`) |
| valid operations | `SEM-PTR-ARITHMETIC` |
| int - ptr is rejected | `ERR-errBinaryMismatch`, `SEM-PTR-ARITHMETIC` |
| ptr + ptr is rejected | `ERR-errBinaryMismatch`, `SEM-PTR-ARITHMETIC` |
| ptr - ptr with different pointee types is rejected | `ERR-errBinaryMismatch`, `SEM-PTR-ARITHMETIC` |
| pointer comparison is rejected | `ERR-errBinaryMismatch`, `SEM-PTR-ARITHMETIC` |
| call through a function pointer | `SEM-PTR-FUNCTION`, `SYN-EXPR-CALL`, `SYN-PTR-DEREF` |
| call through pointer arithmetic | `SEM-PTR-FUNCTION`, `SEM-PTR-ARITHMETIC` |
| unparenthesized call is parsed inside the dereference | `SYN-EXPR-UNARY`, `ERR-errNotCallable` |
| user symbols colliding with syskovy names are escaped | `INT-NIMGEN-NAMES` |

<a id="REF-TEST-MAP-SEMA"></a>
## `tests/tSema.nim`

| Test | Covers |
|---|---|
| infers the element type from the first element | `SEM-ARR-INFERENCE` |
| infers bool elements | `SEM-ARR-INFERENCE` |
| uses the explicit element type | `SEM-ARR-INFERENCE`, `SYN-ARRAY-LITERAL` |
| empty literal with an explicit element type | `SEM-ARR-INFERENCE`, `INT-RUNTIME-ARRAYLIT` |
| empty literal without an element type is rejected | `ERR-errArrayTypeRequired` (`TRG-errArrayTypeRequired-declaration`) |
| mismatched elements are rejected | `ERR-errDoesNotFit`, `SEM-ARR-INFERENCE` |
| mismatched elements are rejected with an explicit type | `ERR-errDoesNotFit`, `SEM-ARR-INFERENCE` |
| void element type is rejected | `ERR-errAllocVoid` (`TRG-errAllocVoid-array-explicit`) |
| void inferred from the first element is rejected | `ERR-errAllocVoid` (`TRG-errAllocVoid-array-inferred`) |
| mutable elements are read as values | `SEM-ARR-INFERENCE` |
| literal inside a loop is rejected | `ERR-errAllocInLoop` (`TRG-errAllocInLoop-array-literal`) |
| literal inside a function declared in a loop is allowed | `ERR-errAllocInLoop` (`TRG-errAllocInLoop-nested-function-allowed`) |
| break inside a function declared in a loop is rejected | `ERR-errContextScope` |
| suggests a close name from the current scope | `ERR-errUnknownSymbol`, `SEM-SCOPE-VISIBILITY` |
| suggests names from outer scopes | `ERR-errUnknownSymbol`, `SEM-SCOPE-VISIBILITY` |
| prefers the closest visible name | `ERR-errUnknownSymbol`, `SEM-SCOPE-VISIBILITY` |
| suggests function names | `ERR-errUnknownSymbol`, `SEM-SCOPE-FUNCTIONS` |
| does not suggest a distant name | `ERR-errUnknownSymbol` |

<a id="REF-TEST-MAP-TYPES"></a>
## `tests/tTypes.nim`

| Test | Covers |
|---|---|
| primitive type names | `SEM-TYPE-INT`, `SEM-TYPE-BOOL`, `SEM-TYPE-VOID`, `SEM-TYPE-STRINGS` |
| mutable types wrap their argument | `SEM-MUT-TYPE`, `SEM-TYPE-SAME` |
| function types keep return and argument types | `SEM-TYPE-FUNC`, `SYN-TYPE-SYNTAX` |
| sameType compares primitives | `SEM-TYPE-SAME` |
| sameType compares mutable wrappers | `SEM-TYPE-SAME` |
| sameType compares function signatures | `SEM-TYPE-SAME` |
| hash is stable for equal types | `SEM-TYPE-SAME` (internal hash contract) |
| function type without parameters | `SYN-TYPE-SYNTAX`, `SEM-TYPE-FUNC` |
| function type with mutable and immutable parameters | `SYN-TYPE-SYNTAX`, `SYN-MUT` |
| nested function types | `SYN-TYPE-SYNTAX`, `SEM-TYPE-FUNC` |

<a id="REF-TEST-MAP-COVERAGE"></a>
## What the tests do not cover

The test suite focuses on successful generation and a representative error per
area. The following are documented and verified through the error pages and
the docs checker rather than through a unit test:

- lexer and parser diagnostics other than `errEmptyFunctionBody`
- overload ambiguity and no-match ordering
- forward/signature/redefinition combinations
- `void*` reaching `ERR-errNonConcreteType`
- unreachable-code ranges in nested blocks
- every `TRG-*` variant on every error page

See the [error index](error-index.md#REF-ERROR-INDEX) and
[verification protocol](../_meta/verification.md#KOVY-VERIFICATION).

## Related

- [Coverage matrix](../_meta/coverage.md#KOVY-COVERAGE)
- [Error index](error-index.md#REF-ERROR-INDEX)
- [Syntax index](syntax-index.md#REF-SYNTAX-INDEX)
- [Semantics index](semantics-index.md#REF-SEMANTICS-INDEX)