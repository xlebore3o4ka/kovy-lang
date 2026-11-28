# Language overview

<!-- doc-id: KOVY-OVERVIEW -->
<!-- status: current -->

<a id="KOVY-OVERVIEW"></a>
Kovy is a small statically typed language implemented in this repository. A
source file is one indentation-sensitive program. There are no modules,
imports, packages, classes, or user-defined types.

## Current feature set

- Scalar types: `int`, `bool`, `void`.
- Mutable and immutable variable declarations.
- Function declarations, nested functions, function values, function types,
  forward declarations, and global overloads.
- Pointers, stack allocation with `alloc`, dereference `#`, address-of
  `addr`, and pointer arithmetic.
- Array literals, which produce a pointer to stack-allocated elements.
- `if` / `elif` / `else`, `while`, `break`, `continue`, and `return`.
- Integer and boolean literals, calls, unary/binary operators, assignment.

There is no string type, character type, floating-point type, record/struct,
enum, union, array value type, slice, closure syntax, `for` loop, `switch`,
exception, module system, or standard library visible to Kovy source.

## Program shape

<a id="SEM-OVERVIEW-PROGRAM"></a>
A program is a global block of statements. Declarations and executable
statements may be interleaved. Function declarations become generated Nim
procedures; other top-level statements become part of a generated top-level
Nim `block`.

```kovy
int mut counter = 0

int next():
  counter = counter + 1
  return counter

int value = next()
```

## Execution model

<a id="SEM-OVERVIEW-MEMORY"></a>
The compiler emits Nim source and imports helper code from `src/syskovy.nim`.
`alloc` and array literals use `alloca`-style stack storage in the generated
program. There is no heap allocator, garbage collector, or `free` operation
in the current language.

Current lifetime checking is intentionally narrow. The compiler does **not**
reject every pointer to a function's stack frame that escapes. The only
lifetime-related diagnostic is `errReturnDanglingMutable`, which covers one
mutable-return case. Do not infer a general borrow checker from its presence.

See [pointers](pointers.md#KOVY-POINTERS) for the current memory rules.

## Compilation stages

<a id="SEM-OVERVIEW-PIPELINE"></a>
1. `src/parser/lexer.nim` turns text into tokens, indentation tokens, and
   statement separators.
2. `src/parser/parser.nim` builds the AST.
3. `src/visitors/sema.nim` resolves names, checks types and contexts, and
   annotates the AST.
4. `src/visitors/nimgen.nim` emits Nim source.
5. The generated Nim source is compiled by Nim; Kovy itself does not run a
   later type checker or linker.

The reusable pipeline is documented in [pipeline](pipeline.md#KOVY-PIPELINE).
The user-facing `kovy` executable provides `check`, which reports diagnostics;
`emit`, which writes generated Nim plus the `syskovy.nim` runtime; and `build`,
which additionally runs the Nim compiler on the generated source. See
[REF-CLI](../reference/cli.md#REF-CLI).

## Reading this reference

- Syntax IDs begin with `SYN-`.
- Semantic rules begin with `SEM-`.
- Errors use `ERR-<ErrorKind>`.
- A concrete reproduction is `TRG-*`.
- [Grammar](grammar.md#KOVY-GRAMMAR) is the canonical syntax summary.

## Related pages

- [Lexical structure](lexical.md#KOVY-LEXICAL)
- [Indentation](indentation.md#KOVY-INDENTATION)
- [Types](types.md#KOVY-TYPES)
- [Error catalogue](../errors/index.md#KOVY-ERRORS-INDEX)