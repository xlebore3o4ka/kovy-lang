# Syntax index

<!-- doc-id: REF-SYNTAX-INDEX -->
<!-- status: current -->

<a id="REF-SYNTAX-INDEX"></a>
This is the complete index of published `SYN-*` anchors. Each row names one
syntax construct and links to the page that defines it. The canonical grammar
is [KOVY-GRAMMAR](../language/grammar.md#KOVY-GRAMMAR). Adding a syntax form
means adding a `SYN-*` section and one row here.

<a id="REF-SYNTAX-LEXICAL"></a>
## Lexical forms

| ID | Construct | Page |
|---|---|---|
| `SYN-LEX-CHARACTERS` | source character set and whitespace | [lexical](../language/lexical.md#SYN-LEX-CHARACTERS) |
| `SYN-LEX-IDENTIFIER` | identifiers | [lexical](../language/lexical.md#SYN-LEX-IDENTIFIER) |
| `SYN-LEX-NUMBER` | decimal number literals | [lexical](../language/lexical.md#SYN-LEX-NUMBER) |
| `SYN-LEX-KEYWORDS` | reserved keywords | [lexical](../language/lexical.md#SYN-LEX-KEYWORDS) |
| `SYN-LEX-OPERATORS` | operators and punctuation | [lexical](../language/lexical.md#SYN-LEX-OPERATORS) |
| `SYN-LEX-LINES` | newline, indentation, and separators | [lexical](../language/lexical.md#SYN-LEX-LINES) |

<a id="REF-SYNTAX-GRAMMAR"></a>
## Grammar productions

| ID | Construct | Page |
|---|---|---|
| `SYN-GRAMMAR-PROGRAM` | program and statements | [grammar](../language/grammar.md#SYN-GRAMMAR-PROGRAM) |
| `SYN-GRAMMAR-TYPES` | type expressions | [grammar](../language/grammar.md#SYN-GRAMMAR-TYPES) |
| `SYN-GRAMMAR-DECLARATIONS` | declarations and functions | [grammar](../language/grammar.md#SYN-GRAMMAR-DECLARATIONS) |
| `SYN-GRAMMAR-BLOCK` | indented and inline blocks | [grammar](../language/grammar.md#SYN-GRAMMAR-BLOCK) |
| `SYN-GRAMMAR-CONTROL` | `if`, `while`, `break`, `continue`, `return` | [grammar](../language/grammar.md#SYN-GRAMMAR-CONTROL) |
| `SYN-GRAMMAR-EXPRESSIONS` | expression ladder | [grammar](../language/grammar.md#SYN-GRAMMAR-EXPRESSIONS) |
| `SYN-GRAMMAR-ALLOC-ARRAY` | allocation and array literal productions | [grammar](../language/grammar.md#SYN-GRAMMAR-ALLOC-ARRAY) |

<a id="REF-SYNTAX-TYPES"></a>
## Types and mutability

| ID | Construct | Page |
|---|---|---|
| `SYN-TYPE-SYNTAX` | `int`, `bool`, `void`, pointers, function types | [types](../language/types.md#SYN-TYPE-SYNTAX) |
| `SYN-MUT` | `mut` positions | [mutability](../language/mutability.md#SYN-MUT) |
| `SYN-PTR-TYPE` | pointer type suffix `T*` | [pointers](../language/pointers.md#SYN-PTR-TYPE) |

<a id="REF-SYNTAX-DECLARATIONS"></a>
## Declarations and functions

| ID | Construct | Page |
|---|---|---|
| `SYN-DECL-GROUP` | variable declaration group | [declarations](../language/declarations.md#SYN-DECL-GROUP) |
| `SYN-FUNC-DECL` | function declaration, forward, and definition | [functions](../language/functions.md#SYN-FUNC-DECL) |
| `SYN-FUNC-PARAMS` | parameter list and parameter groups | [functions](../language/functions.md#SYN-FUNC-PARAMS) |
| `SYN-STMT-DECL` | declaration as a statement | [statements](../language/statements.md#SYN-STMT-DECL) |
| `SYN-STMT-FUNC` | function declaration as a statement | [statements](../language/statements.md#SYN-STMT-FUNC) |

<a id="REF-SYNTAX-STATEMENTS"></a>
## Statements

| ID | Construct | Page |
|---|---|---|
| `SYN-STMT-EXPR` | expression statement | [statements](../language/statements.md#SYN-STMT-EXPR) |
| `SYN-STMT-IF` | `if` / `elif` / `else` | [statements](../language/statements.md#SYN-STMT-IF) |
| `SYN-STMT-WHILE` | `while` | [statements](../language/statements.md#SYN-STMT-WHILE) |
| `SYN-STMT-BREAK` | `break` and `continue` | [statements](../language/statements.md#SYN-STMT-BREAK) |
| `SYN-STMT-RETURN` | `return` with or without a value | [statements](../language/statements.md#SYN-STMT-RETURN) |

<a id="REF-SYNTAX-EXPRESSIONS"></a>
## Expressions

| ID | Construct | Page |
|---|---|---|
| `SYN-EXPR-PRIMARY` | primaries and grouping | [expressions](../language/expressions.md#SYN-EXPR-PRIMARY) |
| `SYN-EXPR-LITERAL` | number and boolean literals | [expressions](../language/expressions.md#SYN-EXPR-LITERAL) |
| `SYN-EXPR-SYMBOL` | symbol references | [expressions](../language/expressions.md#SYN-EXPR-SYMBOL) |
| `SYN-EXPR-CALL` | postfix calls | [expressions](../language/expressions.md#SYN-EXPR-CALL) |
| `SYN-EXPR-UNARY` | unary `+`, `-`, `not`, `#`, `addr` | [expressions](../language/expressions.md#SYN-EXPR-UNARY) |
| `SYN-EXPR-BINARY` | binary and boolean operators | [expressions](../language/expressions.md#SYN-EXPR-BINARY) |
| `SYN-EXPR-ASSIGN` | assignment expression | [expressions](../language/expressions.md#SYN-EXPR-ASSIGN) |
| `SYN-ALLOC` | `alloc` forms | [pointers](../language/pointers.md#SYN-ALLOC) |
| `SYN-PTR-DEREF` | `#expr` | [pointers](../language/pointers.md#SYN-PTR-DEREF) |
| `SYN-PTR-ADDR` | `addr expr` | [pointers](../language/pointers.md#SYN-PTR-ADDR) |
| `SYN-ARRAY-LITERAL` | array literal with optional `of T` | [arrays](../language/arrays.md#SYN-ARRAY-LITERAL) |

<a id="REF-SYNTAX-TABLES"></a>
## Related reference tables

- [All token kinds](tokens.md#REF-TOKENS)
- [All keywords](keywords.md#REF-KEYWORDS)
- [All operators](operators.md#REF-OPERATORS)
- [Precedence](precedence.md#REF-PRECEDENCE)
- [Semantics index](semantics-index.md#REF-SEMANTICS-INDEX)