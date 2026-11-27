# Functions

<!-- doc-id: KOVY-FUNCTIONS -->
<!-- status: current -->

<a id="KOVY-FUNCTIONS"></a>
Functions are declared as statements. They may be global or nested. Global
functions may be overloaded; nested functions may not. Functions are
first-class values through function types.

## Declaration syntax

<a id="SYN-FUNC-DECL"></a>
### Declaration form

```ebnf
functionDecl = type [ "mut" ] IDENT "(" [ parameters ] ")"
               [ ":" block ] ;
```

```kovy
int add(int a, int b):
  return a + b
```

The type before the name is the return type. `mut` before the name marks a
mutable return. A function without a body (no `:`) is a forward declaration.

A function body must contain at least one statement:
`ERR-errEmptyFunctionBody`.

<a id="SYN-FUNC-PARAMS"></a>
### Parameters

Parameters share a type within a group:

```kovy
int f(int a, b, bool c):
  return a
```

The parser reads a type, then a name (or a comma-separated list of names for
that type). A comma followed by an identifier continues the current group; a
comma followed by a type begins a new group. `mut` after a parameter type
marks that individual parameter mutable:

```kovy
void write(int* mut p, int value):
  #p = value
```

Default values are syntactically accepted but sema rejects them:

```kovy
int f(int a = 1):
  return a
```

`ERR-errDefaultForbidden` is emitted for each parameter with a default, and
the default is cleared before further processing.

## Parameter passing

<a id="SEM-FUNC-PARAMS"></a>
### Passing semantics

- A non-`mut` parameter is passed by value.
- A `mut` parameter is passed by reference in generated Nim (`var` parameter).
  Assignments inside the callee affect the caller's storage.
- A mutable argument may be passed to a non-mutable parameter; this is a
  conversion with cost `1` for overload resolution.
- An immutable argument cannot be passed to a `mut` parameter.
- Parameters are local storage for lifetime purposes, but their pointee memory
  belongs to the caller. Current lifetime checking does not model this
  generally.

## Return values

<a id="SEM-FUNC-RETURN"></a>
### Return

- A non-void function must return a value on all paths.
- A `void` function cannot return a value.
- A non-void function cannot use a bare `return` unless it is syntactically
  parsed as no value (next token is `EOS`).
- A mutable-returning function must return a mutable value.
- A mutable-returning function applies `errReturnDanglingMutable` when the
  returned mutable expression's symbol is declared deeper than the function's
  parameter scope. This is a narrow check, not a lifetime analysis.
- Returning an ordinary pointer to local stack storage is currently accepted;
  see [pointers](pointers.md#SEM-PTR-LIFETIME).

## Forward declarations

<a id="SEM-FUNC-FORWARD"></a>
### Forward declarations

A function declaration without a colon has no body:

```kovy
int add(int a, int b)

int use(int x):
  return add(x, x)

int add(int a, int b):
  return a + b
```

Rules:

- Forward declarations are allowed only at global scope.
  A nested bodyless function is `ERR-errForwardOutsideGlobal`.
- A definition is matched to a forward only when its parameter types,
  including parameter mutability, are identical. It must then also match the
  return type and parameter names; otherwise it is
  `ERR-errFuncSignatureMismatch`.
- If the definition has different parameter types or mutability, it is treated
  as a different overload; the original forward remains undefined and is
  reported as `ERR-errUnresolvedForward` at `finalize`.
- A duplicate forward with the same signature and return type is
  `ERR-errFuncRedefinition`; differing return types for the same parameters
  are `ERR-errOverloadByReturnType`.
- A forward with no definition is reported by `finalize` as
  `ERR-errUnresolvedForward`.

## Nested functions and closures

<a id="SEM-FUNC-NESTED"></a>
### Nested functions

A function declaration inside a function body creates a nested function. It
may access visible outer symbols. Generated Nim uses a nested procedure; Nim
may represent captured functions as closures. The Kovy function type has no
explicit environment type.

Nested functions:

- cannot be forward-declared;
- cannot be overloaded;
- cannot reuse a visible name: a collision with a function is
  `errFuncRedefinition`, and a collision with a variable or parameter is
  `errRedeclaration`;
- have their own function context, so `break`, `continue`, and `alloc` inside
  them are not inside an enclosing loop;
- can be passed as function values and called from other functions.

## Calls

<a id="SEM-FUNC-CALL"></a>
### Call checking

A call is a postfix expression. The callee is visited first. If the callee is
a bare global name with more than one overload, `resolveOverloadCall` scores
the arguments and selects a unique cheapest candidate. Otherwise the callee
must have a function type after stripping one mutable wrapper; the generic
path checks arity with `ERR-errWrongArity` and each argument with
`conversionCost`, reporting `ERR-errArgMismatch` for the first failure.

A non-function callee is `ERR-errNotCallable`. An error-typed callee or
argument returns `typeError` without further call diagnostics. A `void` call
may be an expression statement; other expression statements are emitted with
`discard`.

## Function values and function types

<a id="SEM-FUNC-VALUES"></a>
### First-class functions

A function type is `ReturnType(ArgType, ...)`, with `mut` allowed on argument
types. A function value can be stored in a variable or parameter:

```kovy
int add(int a, int b):
  return a + b

int(int, int) f = add
int x = f(1, 2)
```

A bare function name in a context with an expected function type is resolved
by exact type equality. A bare overloaded name without an expected type is
`ERR-errAmbiguousFunctionReference`.

A function pointer is a pointer to a function type:

```kovy
void hello():
  int x = 1

void()* mut dispatch = alloc 1 of void()
#dispatch = hello
(#dispatch)()
```

`#dispatch` has function type; `dispatch()` alone is not callable because the
pointer is a pointer, not a function. `#p()` parses as `#(p())`, so the
parenthesized form is required.

## Recursion and ordering

<a id="SEM-FUNC-ORDER"></a>
### Ordering

- A global function may call itself recursively.
- Calling a function declared later requires a forward declaration; otherwise
  sema reports `errUnknownSymbol`.
- Mutually recursive functions require forward declarations.
- Global overloads are collected as declarations are visited; definition
  order affects which declarations are visible at a call site.

## Generated names

Global functions receive a generated Nim name `encodedNameza<overloadId>`.
Nested functions and non-overloaded declarations use the encoded name.
Overload IDs are assigned by sema. This is observable in tests and in
generated source; details are in
[INT-NIMGEN-NAMES](../internals/nimgen.md#INT-NIMGEN-NAMES).

## Current quirks

<a id="SEM-FUNC-QUIRKS"></a>
- A function declaration without `:` is a forward even when followed by a
  statement on the same line; the parser skips the separator check after
  `nkFuncDecl`.
- Nested functions can be stored and returned, but no explicit closure syntax
  exists.
- A function pointer is not callable without `#`.
- `mut` return is a property of the function, not of its type argument list;
  `int mut f()` and `int* mut f()` are different forms.
- Default parameter values are parsed and then rejected; they never reach
  code generation.

## Diagnostics

- [ERR-errEmptyFunctionBody](../errors/errEmptyFunctionBody.md#ERR-errEmptyFunctionBody)
- [ERR-errDefaultForbidden](../errors/errDefaultForbidden.md#ERR-errDefaultForbidden)
- [ERR-errForwardOutsideGlobal](../errors/errForwardOutsideGlobal.md#ERR-errForwardOutsideGlobal)
- [ERR-errFuncSignatureMismatch](../errors/errFuncSignatureMismatch.md#ERR-errFuncSignatureMismatch)
- [ERR-errFuncRedefinition](../errors/errFuncRedefinition.md#ERR-errFuncRedefinition)
- [ERR-errUnresolvedForward](../errors/errUnresolvedForward.md#ERR-errUnresolvedForward)
- [ERR-errOverloadByReturnType](../errors/errOverloadByReturnType.md#ERR-errOverloadByReturnType)
- [ERR-errAmbiguousFunctionReference](../errors/errAmbiguousFunctionReference.md#ERR-errAmbiguousFunctionReference)
- [ERR-errNotAllPathsReturn](../errors/errNotAllPathsReturn.md#ERR-errNotAllPathsReturn)
- [ERR-errReturnDanglingMutable](../errors/errReturnDanglingMutable.md#ERR-errReturnDanglingMutable)
- [ERR-errImmutableReturn](../errors/errImmutableReturn.md#ERR-errImmutableReturn)
- [ERR-errWrongArity](../errors/errWrongArity.md#ERR-errWrongArity)
- [ERR-errArgMismatch](../errors/errArgMismatch.md#ERR-errArgMismatch)

## Tests

- `tests/tFunc.nim`: grouping, void calls, forward declarations, return paths,
  nested functions, function values, overloads, mutable parameters
- `tests/tPtr.nim`: function pointers, runtime-name escaping