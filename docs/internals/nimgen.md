# Nim generation internals

<!-- doc-id: INT-NIMGEN -->
<!-- status: current -->

<a id="INT-NIMGEN"></a>
`src/visitors/nimgen.nim` converts a sema-annotated AST into Nim source. It
does not compile or run that source. It shares the `ErrorContext` and can add
`errNonConcreteType`.

## Generated-name encoding

<a id="INT-NIMGEN-NAMES"></a>
### Name encoding

Kovy identifiers are encoded so that they cannot collide with Nim syntax and
so that case/underscore distinctions survive Nim's identifier rules.

For every character in a source name, `encChar` produces:

| Character | Encoding |
|---|---|
| `_` | `zu` |
| `z` | `zz` |
| digit | `z` + digit |
| uppercase ASCII | `zc` + lowercase character |
| other | the character unchanged |

`encodeIdent` concatenates these pieces. Examples:

| Kovy name | Encoded |
|---|---|
| `value` | `value` |
| `my_value` | `myzuvalue` |
| `z` | `zz` |
| `x1` | `xz1` |
| `FooBar` | `zcfoozcbar` |

`normSym` then:

1. Computes `identKey`, which removes underscores and lowercases every
   character after the first.
2. If that key equals one of `kovyRuntime`, `kovyAlloca`,
   `kovyAllocaZeroed`, `kovyArrayLit`, or `syskovy`, prefixes the encoded name
   with one literal `z`.
3. If the resulting encoded name is a Nim keyword, wraps it in backticks.

The runtime prefix cannot collide with normal encoding: an input `z` always
becomes `zz`, so a regular encoded name cannot begin with `zk`.

Global functions are mangled as:

```text
encodeIdent(sourceName) & "za" & overloadId
```

The id starts at 1. Nested functions have id 0 and use `normSym` instead.
Function values and direct calls use the mangled name when
`resolvedOverloadId > 0`.

## Declarations and functions

<a id="INT-NIMGEN-EMIT"></a>
### Emission

`emit` prepends an import and wraps the whole program:

```nim
import "<syskovyPath>" as kovyRuntime except kovyAlloca, kovyAllocaZeroed, kovyArrayLit

block:
  ...
```

The path is backslash-normalized to `/`. `syskovyPath` defaults to
`src/syskovy` relative to the nimgen source file. `kovy emit` passes
`./syskovy` so the generated file imports the runtime written next to it.

Statements:

| Kovy | Nim |
|---|---|
| initialized immutable declaration | `let name: T = value` |
| mutable or uninitialized declaration | `var name: T[ = value]` |
| multiple declarations in one group | separated by `; ` |
| assignment expression statement | `lhs = rhs` (no parentheses or `discard`) |
| non-void expression statement | `discard expr` |
| void call statement | call without `discard` |
| `if`/`elif`/`else` | Nim `if`/`elif`/`else` blocks |
| `while` | Nim `while` block |
| `break`, `continue`, `return` | matching Nim statements |
| global/nested function | Nim `proc`, with generated name |

A function body uses ` =` as the block marker. A bodyless function emits only
the `proc` signature, which is a Nim forward declaration. A block normally
emits `:`; nested blocks use indentation.

`visit(Block)` appends `;` after simple statements and a newline after
`Branch`, `While`, and `FuncDecl`. This produces valid Nim for well-formed
ASTs but is not a pretty-printer; exact whitespace is an implementation detail.

## Calls and assignment

<a id="INT-NIMGEN-CALLS"></a>
### Calls

A direct call to a resolved global overload prints the mangled callee name.
Otherwise it prints the callee expression. Arguments are comma-separated in
source order. Calls are always emitted with parentheses.

`#p()` is parsed as `#(p())`, so code generation follows that AST. To call a
function pointer, the source must write `(#p)()`, which emits `(p)[]()`.

<a id="INT-NIMGEN-ASSIGN"></a>
### Assignment

An assignment expression is emitted as `(lhs = rhs; lhs)`. Binary operands are
parenthesized when they are themselves binary.

If the left side is a call, nimgen uses a temporary to evaluate the call once:

```nim
(block:
  let `kovy tmp 0` = addr callee(...)
  `kovy tmp 0`[] = rhs
  `kovy tmp 0`[])
```

Temporary names are backticked and use a per-Nimgen counter.

A top-level assignment statement is special-cased to omit the surrounding
parentheses and returned value: it emits `lhs = rhs`.

## Types

<a id="INT-NIMGEN-TYPES"></a>
### Nim type mapping

| Kovy | Nim |
|---|---|
| `int` | `int` |
| `bool` | `bool` |
| `void` | `void` |
| `mut T` | `var T` in parameter/return position |
| `T*` | `ptr T` |
| `func*` | `ptr (proc (...): ...)` |
| `R(A, B)` function type | `proc (a0: A, a1: B): R` |
| mutable function argument | `aN: var A` |

Function types use synthetic parameter names `a0`, `a1`, and so on. They are
closures in Nim; the Kovy type has no environment type.

## Memory

<a id="INT-NIMGEN-MEMORY"></a>
### Allocation and array literals

`alloc` emits:

```nim
cast[<ptr type>](kovyRuntime.kovyAlloca((<count>) * sizeof(<element type>)))
```

If the element type is a function type, it uses `kovyAllocaZeroed` instead so
Nim closure slots are safe to assign. `void` element allocation never reaches
this path because sema rejects it.

An array literal emits:

```nim
kovyRuntime.kovyArrayLit(<count>, <element type>[, <element>, ...])
```

The macro allocates zeroed storage and assigns each element in order. It
returns a pointer to the first element. See
[INT-RUNTIME-ARRAYLIT](runtime.md#INT-RUNTIME-ARRAYLIT).

`#expr` emits `(expr)[]`. `addr expr` emits `addr (expr)`. Pointer arithmetic
is emitted as ordinary `+`/`-`; `syskovy` supplies the overloads.

## Non-concrete types

<a id="INT-NIMGEN-NONCONCRETE"></a>
### `errNonConcreteType`

`nimType` reports `errNonConcreteType` when it encounters a pointer whose
immediate pointee is `void`. It still returns Nim `pointer` for that inner
type so generation can continue.

This check is in nimgen, not sema. Programs such as `void* p` therefore pass
lexer, parser, sema, and `finalize`, and fail only when nimgen runs. A nested
void pointer (`void**`) reports one error at the inner `void*` and then emits
`ptr pointer`.

Nimgen can report the same error more than once if the same non-concrete type
is emitted in several places, for example in several declarations or function
signatures.

## Runtime name collisions

<a id="INT-NIMGEN-RESERVED"></a>
### Runtime names

The generated import excludes three helper names so a user declaration cannot
be confused with the runtime macro/template. User symbols whose encoded names
collide with runtime or module names are prefixed with `z`. Examples from
`tests/tPtr.nim`:

| Source | Generated |
|---|---|
| `kovyruntime` | `zkovyruntime` |
| `kovyalloca` | `zkovyalloca` |
| `kovyarraylit` | `zkovyarraylit` |
| `syskovy` | `zsyskovy` |

The comparison is case-insensitive after the first character and ignores
underscores, matching Nim identifier rules.

## Implementation

- `src/visitors/nimgen.nim`: all emission
- `src/syskovy.nim`: runtime helpers
- `tests/tFunc.nim`, `tests/tPtr.nim`: generated-source assertions