# Hello world

<!-- doc-id: KOVY-GUIDE-HELLO -->
<!-- status: current -->

<a id="KOVY-GUIDE-HELLO"></a>
This guide is the shortest path to a complete, accepted Kovy program. It also
states the first surprise clearly: Kovy currently has no strings, no printing,
and no program input. A Kovy program computes values; it does not write to a
terminal.

## The smallest program

<!-- expect-errors: OK -->
```kovy
int answer():
  return 42

int result = answer()
```

This program declares a function, calls it once at global scope, and stores the
result in a global variable. It passes lexing, parsing, sema, `finalize`, and
Nim generation.

A "hello world" in the usual sense cannot be written yet: there is no string
literal and no `echo`/`print`. The closest complete program is a named function
that computes a value.

## A `main`-shaped program

`main` is not special. Any top-level statement runs when the generated Nim
program starts. A function named `main` is called only if some statement calls
it.

<!-- expect-errors: OK -->
```kovy
void hello():
  int message = 42

void main():
  hello()

main()
```

The top-level `main()` is an expression statement. Because `main` returns
`void`, generated Nim emits the call directly, without `discard`.

## Values and mutability

Immutability is the default. Add `mut` after a type to allow assignment.

<!-- expect-errors: OK -->
```kovy
int mut total = 0
int mut i = 0
while i < 5:
  total = total + i
  i = i + 1

int result = total
```

`i < 5` is a boolean condition. `total` and `i` are writable because both are
declared `int mut`. A plain `int` would reject the assignments with
`ERR-errImmutableAssignment`.

## Functions and return values

A non-void function must return a value on every syntactic path. `if` without
`else` is not exhaustive for this check.

<!-- expect-errors: OK -->
```kovy
int abs(int x):
  if x < 0:
    return -x
  else:
    return x

int value = abs(-7)
```

`-x` is unary minus on an `int`; the result is `int`. The `if`/`else` has a
return in both branches, so the all-paths-return check succeeds.

## Reading a diagnostic

<!-- expect-errors: errUnknownSymbol -->
```kovy
int value = missing
```

The compiler reports `ERR-errUnknownSymbol`, including a suggestion when a
close visible name exists. Diagnostics are collected in source order and do
not stop compilation immediately. See
[the error catalogue](../errors/index.md#KOVY-ERRORS-INDEX).

## What runs, and what does not

The pipeline produces generated Nim source. `kovy check` reports diagnostics;
`kovy emit` writes the generated `.nim` file and the `syskovy.nim` runtime;
`kovy build` also invokes Nim to link a native binary. See the
[CLI reference](../reference/cli.md#REF-CLI) and the
[compilation pipeline](../language/pipeline.md#SEM-PIPELINE-STAGES).

## Next steps

- [Functions and overloads](functions-overloads.md#KOVY-GUIDE-FUNCTIONS)
- [Pointers and allocation](pointers-alloc.md#KOVY-GUIDE-POINTERS)
- [Arrays](arrays.md#KOVY-GUIDE-ARRAYS)
- [RPN interpreter](rpn.md#KOVY-GUIDE-RPN)