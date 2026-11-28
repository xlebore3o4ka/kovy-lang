# Compilation pipeline

<!-- doc-id: KOVY-PIPELINE -->
<!-- status: current -->

<a id="KOVY-PIPELINE"></a>
A Kovy source string passes through four cooperating components. Errors are
collected in one `ErrorContext`; components do not throw for ordinary source
errors.

## Stages

<a id="SEM-PIPELINE-STAGES"></a>
### Stages

1. **Lexing.** `newLexer(source, errors, file)` over `src/parser/lexer.nim`.
   It produces tokens, indentation tokens, and statement separators on demand.
2. **Parsing.** `newParser(lexer, errors).parse()` over
   `src/parser/parser.nim`. It produces one global `nkBlock`.
3. **Semantic analysis.** `newSema(errors, files)` visits the AST and then
   `finalize()` resolves outstanding forward declarations.
4. **Nim generation.** `newNimgen(errors).emit(tree)` over
   `src/visitors/nimgen.nim` returns a Nim source string.

The generated Nim imports `src/syskovy.nim` and must still be compiled by Nim.
The Kovy front-end does not invoke the Nim compiler, link the program, or run
it; `kovy build` is a separate wrapper that runs Nim on the generated source.

<a id="SEM-PIPELINE-ERRORS"></a>
### Error accumulation and short-circuiting

- Lexical and parser diagnostics are added to the same `ErrorContext` as sema
  diagnostics.
- The parser attempts recovery and keeps parsing after many errors.
- Sema continues through the tree after an error. An `typeError` result
  suppresses many follow-up errors, but not all of them.
- `finalize` runs after the visit and can add unresolved-forward errors.
- The caller decides whether to run nimgen. The test helper runs nimgen only
  when no error exists after sema and `finalize`.
- Nimgen reuses the same context and can add `errNonConcreteType`; it does not
  stop with an exception.
- Nimgen may still return a string after errors. Callers must inspect the
  context before using the generated source.

The pipeline does not stop at the first error. Diagnostics are ordered by the
order in which components add them: lexer/parser first, then sema, then
`finalize`, then nimgen.

## Programmatic driver

The reusable sequence is:

```nim
import parser/[lexer, parser]
import errors
import visitors/[sema, nimgen]

let source = "int x = 1\n"
let ctx = newErrorContext("src/error_locales/en.json")
let files = FileTracker()
let file = files.newFile("<string>", source)

let lexer = newLexer(source, ctx, file)
let tree = newParser(lexer, ctx).parse()

let sema = newSema(ctx, files)
discard sema.visit(tree)
sema.finalize()

var generated = ""
if not ctx.hasErrors():
  generated = newNimgen(ctx).emit(tree)

if ctx.hasErrors():
  for err in ctx.errors:
    echo ctx.formatError(files, err)
else:
  echo generated
```

`FileTracker` interns every source name and stores its lines. The same tracker
must be used for formatting diagnostics, because an `Error` stores only a
numeric file id.

## Command-line entry point

<a id="SEM-PIPELINE-CLI"></a>
The user-facing executable is `bin/kovy`, built from `src/kovy.nim`. The current
command line provides `check`, `emit`, and `build`:

- all three accept a source file, `-`, or piped stdin;
- all three load a locale from `error_locales` or from `--locale-path`;
- all three run lexer, parser, sema, and `finalize`;
- all three run `nimgen` when no earlier error exists; `check --no-nimgen` stops
  after sema;
- `check` prints formatted diagnostics to stderr;
- `emit` writes generated Nim and `syskovy.nim`, or prints the Nim to stdout
  with `-o -`;
- `build` writes the generated files to a temporary directory and runs
  `nim c` on them, optionally keeping the files with `--keep-nim`.

The command line is documented in
[REF-CLI](../reference/cli.md#REF-CLI). The current source pipeline does not use
`src/visitors/codegen.nim`; that file is an LLVM-oriented historical path marked
postponed.

## Generated source shape

<a id="SEM-PIPELINE-GENERATED"></a>
Nimgen emits:

```nim
import "<path>/src/syskovy" as kovyRuntime except kovyAlloca, kovyAllocaZeroed, kovyArrayLit

block:
  ...
```

The top-level Kovy block becomes one Nim `block`. Global function declarations
become Nim `proc`s; other global statements are emitted in order inside the
block. Function calls use generated names, `alloc` calls runtime alloca
helpers, and array literals call the `kovyArrayLit` macro.

See [INT-NIMGEN-EMIT](../internals/nimgen.md#INT-NIMGEN-EMIT) and
[INT-RUNTIME](../internals/runtime.md#INT-RUNTIME).

## Diagnostics and source locations

<a id="SEM-PIPELINE-DIAGNOSTICS"></a>
Each `Error` stores `kind`, placeholders, line, column, length, and file id.
`formatError` prints the `[ErrorKind]` name, source line, a marker, the
localized message, and optional addinfo. The exact format is documented in
[INT-ERROR-FORMATTING](../internals/error-system.md#INT-ERROR-FORMATTING).

The locale file is required. `newErrorContext` raises `LocaleLoadError` when
the path does not exist. A missing locale key would fail at formatting time;
all current `ErrorKind`s have keys.

## Current quirks

<a id="SEM-PIPELINE-QUIRKS"></a>
- Lexing is lazy. A "lexer stage" is interleaved with parsing, so lexer errors
  are discovered while the parser requests tokens.
- Nimgen is the only stage with a source check that sema can pass and code
  generation can still reject: `void*`.
- `kovy check` stops at diagnostics; `kovy emit` writes generated Nim but does
  not compile it; `kovy build` writes it to a temporary directory and invokes
  Nim.
- The old LLVM code generator is not wired into the pipeline.
- The parser and sema accept some programs that generated Nim rejects. Docs
  distinguish Kovy diagnostics from later Nim diagnostics.

## Related pages

- [Lexical structure](lexical.md#KOVY-LEXICAL)
- [Indentation](indentation.md#KOVY-INDENTATION)
- [Grammar](grammar.md#KOVY-GRAMMAR)
- [Internals: sema](../internals/sema.md#INT-SEMA)
- [Internals: nimgen](../internals/nimgen.md#INT-NIMGEN)
- [Internals: error system](../internals/error-system.md#INT-ERROR-SYSTEM)
- [Verification](../_meta/verification.md#KOVY-VERIFICATION)