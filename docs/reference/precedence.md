# Precedence and associativity

<!-- doc-id: REF-PRECEDENCE -->
<!-- status: current -->

<a id="REF-PRECEDENCE"></a>
Kovy uses the fixed precedence ladder implemented by the recursive-descent
parser in `src/parser/parser.nim`. There is no user-defined precedence and no
parenthesis-free way to change it. Parentheses group any expression.

<a id="REF-PRECEDENCE-TABLE"></a>
## Ladder

From lowest binding to highest binding:

| Level | Operators | Associativity | Parser procedure |
|---|---|---|---|
| 1 (lowest) | `=` | right | `parseAssignment` |
| 2 | `or` | left | `parseOr` |
| 3 | `and` | left | `parseAnd` |
| 4 | `>`, `<`, `>=`, `<=`, `==`, `!=` | left | `parseCmp` |
| 5 | `+`, `-` | left | `parseAddSub` |
| 6 | `*`, `/` | left | `parseMulDiv` |
| 7 | unary `+`, `-`, `not`, `#`, `addr` | prefix, right-nested | `parseUnary` |
| 8 | postfix call `(...)` | left | `parsePostfix` |
| 9 (highest) | primary, grouping `(...)` | n/a | `parsePrimary` |

`parseExpr` is `parseAssignment`, so a full expression always starts at the
assignment level.

<a id="REF-PRECEDENCE-NOTES"></a>
## Consequences

- All six comparison operators share one level. `a < b == c` parses as
  `(a < b) == c`, and `1 < 2 < 3` parses as `(1 < 2) < 3`, which then fails
  type checking because a `bool` is compared with an `int`.
- `and` binds tighter than `or`. `a or b and c` parses as `a or (b and c)`.
- `not`, unary `+`, unary `-`, `#`, and `addr` bind tighter than `*` and `/`.
  `not a and b` parses as `(not a) and b`; `-a * b` parses as `(-a) * b`.
- Prefix unary operators nest to the right: `--x` is `-(-x)` and
  `not not b` is `not (not b)`.
- Postfix calls bind tighter than unary operators. `#p()` is `#(p())`, while
  `(#p)()` dereferences first and then calls.
- Assignment is right-associative and has the lowest precedence. `a = b = 1`
  parses as `a = (b = 1)`. `a = b or c` parses as `a = (b or c)`.
- Because the left side of `=` is parsed as an `or` expression, `a or b = c`
  parses as `(a or b) = c`; the assignment then fails the mutable-lvalue
  check.
- `alloc` and array literals are primaries. `alloc int + 1` parses as
  `(alloc int) + 1` because the short allocation form ends at the type.
- `*` is both multiplicative and a type suffix. The parser only reads it as a
  pointer constructor inside `parseType`, never in an expression.

<a id="REF-PRECEDENCE-EXAMPLES"></a>
## Examples

```kovy
int a = 2 + 3 * 4
int b = (2 + 3) * 4
bool c = 1 < 2 and 2 < 3
bool d = not (1 == 2) or true
int mut x = 1
x = x + 1
```

The first initializes `a` to `14`; the second to `20`. The boolean expressions
show `and` binding tighter than `or` and `not` binding tighter than both.

## Related

- [Operator reference](operators.md#REF-OPERATORS)
- [Expressions](../language/expressions.md#SYN-EXPR-BINARY)
- [Canonical grammar](../language/grammar.md#SYN-GRAMMAR-EXPRESSIONS)
- [Parsing precedence coverage](../_meta/coverage.md#COVERAGE-PARSER)