# Kovy language documentation

<a id="KOVY-DOCS-HOME"></a>
This directory is the reference for the Kovy language as currently implemented
in this repository. It describes syntax, semantics, generated-code-visible
behaviour, and every diagnostic currently defined by the compiler.

The documentation is intentionally written as many small pages. Each useful
statement has a stable ID, so other documents, issues, and commit messages can
link to it without depending on heading text or line numbers.

## Start here

- [Language overview](language/overview.md#KOVY-OVERVIEW)
- [Complete grammar](language/grammar.md#KOVY-GRAMMAR)
- [Types](language/types.md#KOVY-TYPES)
- [Expressions](language/expressions.md#KOVY-EXPRESSIONS)
- [Functions and overloads](language/functions.md#KOVY-FUNCTIONS)
- [Pointers](language/pointers.md#KOVY-POINTERS)
- [Arrays](language/arrays.md#KOVY-ARRAYS)
- [Error catalogue](errors/index.md#KOVY-ERRORS-INDEX)

## Conventions

- Normative statements are marked with `SEM-*` rules.
- Syntax constructs are marked with `SYN-*` IDs.
- Diagnostics are `ERR-<ErrorKind>`; individual reproductions are `TRG-*`.
- Prose is English; source code, identifiers, and diagnostics are quoted
  exactly as the compiler produces them.
- "Current" means the behaviour of the code in this repository. It does not
  imply that the behaviour is complete, safe, or intended for the future.
- Source locations are given by module and procedure name, never by line
  number.

## Documentation maintenance

Read [_meta/id-scheme.md](_meta/id-scheme.md) before adding a page. Use
[_meta/page-templates.md](_meta/page-templates.md) for new pages. Update
[_meta/coverage.md](_meta/coverage.md) whenever a token, syntax form, type,
visitor branch, or error is added. The validation procedure is recorded in
[_meta/verification.md](_meta/verification.md).

The implementation plan that produced this tree is kept in [TODO.md](TODO.md).
It is historical planning material, not a language specification.