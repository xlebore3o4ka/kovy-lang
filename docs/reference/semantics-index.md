# Semantics index

<!-- doc-id: REF-SEMANTICS-INDEX -->
<!-- status: current -->

<a id="REF-SEMANTICS-INDEX"></a>
This is the complete index of published `SEM-*` anchors. Each row names one
normative rule and links to its definition. Rules describe the current
implementation, including current quirks. Adding a semantic rule means adding a
`SEM-*` section and one row here.

<a id="REF-SEMANTICS-OVERVIEW"></a>
## Program model and pipeline

| ID | Rule | Page |
|---|---|---|
| `SEM-OVERVIEW-PROGRAM` | program shape and top-level statements | [overview](../language/overview.md#SEM-OVERVIEW-PROGRAM) |
| `SEM-OVERVIEW-MEMORY` | execution and memory model | [overview](../language/overview.md#SEM-OVERVIEW-MEMORY) |
| `SEM-OVERVIEW-PIPELINE` | compilation stages | [overview](../language/overview.md#SEM-OVERVIEW-PIPELINE) |
| `SEM-PIPELINE-STAGES` | lexer, parser, sema, nimgen | [pipeline](../language/pipeline.md#SEM-PIPELINE-STAGES) |
| `SEM-PIPELINE-ERRORS` | error accumulation and short-circuiting | [pipeline](../language/pipeline.md#SEM-PIPELINE-ERRORS) |
| `SEM-PIPELINE-CLI` | command-line entry point | [pipeline](../language/pipeline.md#SEM-PIPELINE-CLI) |
| `SEM-PIPELINE-GENERATED` | generated source shape | [pipeline](../language/pipeline.md#SEM-PIPELINE-GENERATED) |
| `SEM-PIPELINE-DIAGNOSTICS` | source locations in diagnostics | [pipeline](../language/pipeline.md#SEM-PIPELINE-DIAGNOSTICS) |
| `SEM-PIPELINE-QUIRKS` | pipeline quirks | [pipeline](../language/pipeline.md#SEM-PIPELINE-QUIRKS) |

<a id="REF-SEMANTICS-LEXING"></a>
## Lexing, indentation, and separators

| ID | Rule | Page |
|---|---|---|
| `SEM-LEX-INVALID` | invalid characters | [lexical](../language/lexical.md#SEM-LEX-INVALID) |
| `SEM-INDENT-CHARACTER` | one indentation character type per file | [indentation](../language/indentation.md#SEM-INDENT-CHARACTER) |
| `SEM-INDENT-EOS` | newlines, semicolons, and separators | [indentation](../language/indentation.md#SEM-INDENT-EOS) |
| `SEM-INDENT-BLOCK` | parser block rules | [indentation](../language/indentation.md#SEM-INDENT-BLOCK) |
| `SEM-INDENT-QUIRKS` | indentation quirks | [indentation](../language/indentation.md#SEM-INDENT-QUIRKS) |
| `SEM-GRAMMAR-SEPARATORS` | statement separator acceptance | [grammar](../language/grammar.md#SEM-GRAMMAR-SEPARATORS) |
| `SEM-STMT-SEPARATORS` | separators around compound statements | [statements](../language/statements.md#SEM-STMT-SEPARATORS) |

<a id="REF-SEMANTICS-TYPES"></a>
## Types and conversions

| ID | Rule | Page |
|---|---|---|
| `SEM-TYPE-INT` | `int` | [types](../language/types.md#SEM-TYPE-INT) |
| `SEM-TYPE-BOOL` | `bool` | [types](../language/types.md#SEM-TYPE-BOOL) |
| `SEM-TYPE-VOID` | `void` | [types](../language/types.md#SEM-TYPE-VOID) |
| `SEM-TYPE-INTERNAL` | literal, mutable, and error types | [types](../language/types.md#SEM-TYPE-INTERNAL) |
| `SEM-TYPE-FITS` | `fits` | [types](../language/types.md#SEM-TYPE-FITS) |
| `SEM-TYPE-CONVERSION-COST` | `conversionCost` | [types](../language/types.md#SEM-TYPE-CONVERSION-COST) |
| `SEM-TYPE-SAME` | `sameType` | [types](../language/types.md#SEM-TYPE-SAME) |
| `SEM-TYPE-STRINGS` | diagnostic type strings | [types](../language/types.md#SEM-TYPE-STRINGS) |
| `SEM-TYPE-LITERALS` | literal typing | [types](../language/types.md#SEM-TYPE-LITERALS) |
| `SEM-TYPE-PTR` | pointer types | [types](../language/types.md#SEM-TYPE-PTR) |
| `SEM-TYPE-FUNC` | function types | [types](../language/types.md#SEM-TYPE-FUNC) |
| `SEM-TYPE-NO-IMPLICIT` | no implicit conversions | [types](../language/types.md#SEM-TYPE-NO-IMPLICIT) |

<a id="REF-SEMANTICS-DECLARATIONS"></a>
## Declarations

| ID | Rule | Page |
|---|---|---|
| `SEM-DECL-GROUP-ORDER` | grouped names and evaluation order | [declarations](../language/declarations.md#SEM-DECL-GROUP-ORDER) |
| `SEM-DECL-RULES` | declaration checking | [declarations](../language/declarations.md#SEM-DECL-RULES) |
| `SEM-DECL-INIT` | initialization and `fits` | [declarations](../language/declarations.md#SEM-DECL-INIT) |
| `SEM-DECL-VOID` | `void` variables | [declarations](../language/declarations.md#SEM-DECL-VOID) |

<a id="REF-SEMANTICS-EXPRESSIONS"></a>
## Expressions

| ID | Rule | Page |
|---|---|---|
| `SEM-EXPR-EVAL` | evaluation order and grouping | [expressions](../language/expressions.md#SEM-EXPR-EVAL) |
| `SEM-EXPR-STATEMENT` | expression statements | [expressions](../language/expressions.md#SEM-EXPR-STATEMENT) |
| `SEM-EXPR-QUIRKS` | expression quirks | [expressions](../language/expressions.md#SEM-EXPR-QUIRKS) |

<a id="REF-SEMANTICS-FUNCTIONS"></a>
## Functions and overloads

| ID | Rule | Page |
|---|---|---|
| `SEM-FUNC-PARAMS` | parameter passing | [functions](../language/functions.md#SEM-FUNC-PARAMS) |
| `SEM-FUNC-RETURN` | return checking | [functions](../language/functions.md#SEM-FUNC-RETURN) |
| `SEM-FUNC-FORWARD` | forward declarations | [functions](../language/functions.md#SEM-FUNC-FORWARD) |
| `SEM-FUNC-NESTED` | nested functions and closures | [functions](../language/functions.md#SEM-FUNC-NESTED) |
| `SEM-FUNC-VALUES` | first-class function values | [functions](../language/functions.md#SEM-FUNC-VALUES) |
| `SEM-FUNC-ORDER` | declaration ordering | [functions](../language/functions.md#SEM-FUNC-ORDER) |
| `SEM-FUNC-QUIRKS` | function quirks | [functions](../language/functions.md#SEM-FUNC-QUIRKS) |
| `SEM-OVL-SIGNATURE` | overload signature identity | [overloads](../language/overloads.md#SEM-OVL-SIGNATURE) |
| `SEM-OVL-RESOLUTION` | call-site resolution algorithm | [overloads](../language/overloads.md#SEM-OVL-RESOLUTION) |
| `SEM-OVL-COSTS` | overload cost examples | [overloads](../language/overloads.md#SEM-OVL-COSTS) |
| `SEM-OVL-REFERENCES` | expected function types | [overloads](../language/overloads.md#SEM-OVL-REFERENCES) |
| `SEM-OVL-FORWARD` | forwards and overloads | [overloads](../language/overloads.md#SEM-OVL-FORWARD) |
| `SEM-OVL-LIMITS` | overload limitations | [overloads](../language/overloads.md#SEM-OVL-LIMITS) |

<a id="REF-SEMANTICS-MUTABILITY"></a>
## Mutability

| ID | Rule | Page |
|---|---|---|
| `SEM-MUT-TYPE` | mutable type wrapper | [mutability](../language/mutability.md#SEM-MUT-TYPE) |
| `SEM-MUT-WRITE` | expression write permission | [mutability](../language/mutability.md#SEM-MUT-WRITE) |
| `SEM-MUT-ASSIGN` | symbol assignment | [mutability](../language/mutability.md#SEM-MUT-ASSIGN) |
| `SEM-MUT-RETURN` | mutable-returning functions | [mutability](../language/mutability.md#SEM-MUT-RETURN) |
| `SEM-MUT-PTR` | mutable pointers | [mutability](../language/mutability.md#SEM-MUT-PTR) |
| `SEM-MUT-LIFETIME-LIMIT` | current lifetime limitation | [mutability](../language/mutability.md#SEM-MUT-LIFETIME-LIMIT) |

<a id="REF-SEMANTICS-POINTERS"></a>
## Pointers and allocation

| ID | Rule | Page |
|---|---|---|
| `SEM-PTR-ALLOC-MEMORY` | allocation storage | [pointers](../language/pointers.md#SEM-PTR-ALLOC-MEMORY) |
| `SEM-PTR-DEREF-GRANT` | write permission through `#` | [pointers](../language/pointers.md#SEM-PTR-DEREF-GRANT) |
| `SEM-PTR-ARITHMETIC` | pointer arithmetic | [pointers](../language/pointers.md#SEM-PTR-ARITHMETIC) |
| `SEM-PTR-FUNCTION` | function pointers | [pointers](../language/pointers.md#SEM-PTR-FUNCTION) |
| `SEM-PTR-LIFETIME` | current pointer lifetime behavior | [pointers](../language/pointers.md#SEM-PTR-LIFETIME) |
| `SEM-PTR-RULES` | other pointer rules | [pointers](../language/pointers.md#SEM-PTR-RULES) |

<a id="REF-SEMANTICS-ARRAYS"></a>
## Arrays

| ID | Rule | Page |
|---|---|---|
| `SEM-ARR-INFERENCE` | element type inference | [arrays](../language/arrays.md#SEM-ARR-INFERENCE) |
| `SEM-ARR-MEMORY` | storage and allocation | [arrays](../language/arrays.md#SEM-ARR-MEMORY) |
| `SEM-ARR-NESTED` | nested array literals | [arrays](../language/arrays.md#SEM-ARR-NESTED) |
| `SEM-ARR-FUNCTIONS` | arrays of functions | [arrays](../language/arrays.md#SEM-ARR-FUNCTIONS) |
| `SEM-ARR-RULES` | array restrictions | [arrays](../language/arrays.md#SEM-ARR-RULES) |

<a id="REF-SEMANTICS-SCOPES"></a>
## Scopes

| ID | Rule | Page |
|---|---|---|
| `SEM-SCOPE-KINDS` | scope kinds | [scopes](../language/scopes.md#SEM-SCOPE-KINDS) |
| `SEM-SCOPE-VISIBILITY` | visibility order | [scopes](../language/scopes.md#SEM-SCOPE-VISIBILITY) |
| `SEM-SCOPE-SHADOWING` | shadowing rules | [scopes](../language/scopes.md#SEM-SCOPE-SHADOWING) |
| `SEM-SCOPE-FUNCTIONS` | function names and overload sets | [scopes](../language/scopes.md#SEM-SCOPE-FUNCTIONS) |
| `SEM-SCOPE-LIFETIME` | leaving a scope | [scopes](../language/scopes.md#SEM-SCOPE-LIFETIME) |
| `SEM-SCOPE-CONTEXT` | context scopes | [scopes](../language/scopes.md#SEM-SCOPE-CONTEXT) |
| `SEM-SCOPE-QUIRKS` | scope quirks | [scopes](../language/scopes.md#SEM-SCOPE-QUIRKS) |

<a id="REF-SEMANTICS-STATEMENTS"></a>
## Statements and control flow

| ID | Rule | Page |
|---|---|---|
| `SEM-STMT-BLOCK` | block forms | [statements](../language/statements.md#SEM-STMT-BLOCK) |
| `SEM-STMT-SCOPE` | statement scope behavior | [statements](../language/statements.md#SEM-STMT-SCOPE) |
| `SEM-FLOW-CONTEXT` | execution contexts | [control flow](../language/control-flow.md#SEM-FLOW-CONTEXT) |
| `SEM-FLOW-BRANCH` | `if` / `elif` / `else` | [control flow](../language/control-flow.md#SEM-FLOW-BRANCH) |
| `SEM-FLOW-LOOP` | `while` | [control flow](../language/control-flow.md#SEM-FLOW-LOOP) |
| `SEM-FLOW-RETURN` | return checking | [control flow](../language/control-flow.md#SEM-FLOW-RETURN) |
| `SEM-FLOW-RETURN-PATHS` | all-paths-return analysis | [control flow](../language/control-flow.md#SEM-FLOW-RETURN-PATHS) |
| `SEM-FLOW-RETURN-DANGLING` | mutable-return dangling check | [control flow](../language/control-flow.md#SEM-FLOW-RETURN-DANGLING) |
| `SEM-FLOW-UNREACHABLE` | unreachable code | [control flow](../language/control-flow.md#SEM-FLOW-UNREACHABLE) |
| `SEM-FLOW-EXITS-LOOP` | break detection for `while true` | [control flow](../language/control-flow.md#SEM-FLOW-EXITS-LOOP) |

## Related

- [Syntax index](syntax-index.md#REF-SYNTAX-INDEX)
- [Error index](error-index.md#REF-ERROR-INDEX)
- [Coverage matrix](../_meta/coverage.md#KOVY-COVERAGE)