# Functions and overloads

<!-- doc-id: KOVY-GUIDE-FUNCTIONS -->
<!-- status: current -->

<a id="KOVY-GUIDE-FUNCTIONS"></a>
A Kovy function is declared with a return type, a name, a parameter list, a
colon, and an indented body. A declaration without a colon and body is a
forward declaration at global scope.

## A basic function

<!-- expect-errors: OK -->
```kovy
int add(int a, int b):
  return a + b

int result = add(1, 2)
```

Parameters are positional. Each parameter has a type and a name. A trailing
comma in the parameter list is allowed.

## Grouped parameters

A type can introduce several names at once. Each name becomes a separate
parameter.

<!-- expect-errors: OK -->
```kovy
int add(int a, b):
  return a + b

int result = add(1, 2)
```

The generated Nim has `(a: int, b: int)`. A group can also change type:
`int f(int a, bool b)` declares one `int` and one `bool`.

Mutability applies to every name in the group:

<!-- expect-errors: OK -->
```kovy
int bump(int mut a, b):
  a = a + 1
  b = b + 1
  return a + b

int mut x = 1
int mut y = 2
int result = bump(x, y)
```

Both parameters are `mut int`, and both arguments must be mutable.

## Return values and paths

A non-void function must return on every syntactic path. The check is
conservative and does not evaluate conditions.

<!-- expect-errors: OK -->
```kovy
int max(int a, int b):
  if a > b:
    return a
  else:
    return b

int result = max(3, 5)
```

`while true` counts as non-fallthrough only when the condition is the literal
`true` and the body contains no syntactic `break`. A bare `return` is only
allowed in a `void` function.

## Overloads

Overloads are global and are distinguished by parameter types. Return type
alone does not distinguish them.

<!-- expect-errors: OK -->
```kovy
int pick(int a):
  return a

int pick(bool a):
  return 1

int first = pick(7)
int second = pick(true)
```

Resolution scores every argument with `conversionCost`, keeps the candidates
with the lowest total cost, and selects a unique minimum. A literal-to-`int`
or literal-to-`bool` conversion costs 1; an exact match costs 0.

An overloaded name used as a value needs an expected function type:

<!-- expect-errors: OK -->
```kovy
int pick(int a):
  return a

int pick(bool a):
  return 1

int(int) choose = pick
int value = choose(7)
```

Without that expected type the reference is ambiguous:

<!-- expect-errors: errAmbiguousFunctionReference -->
```kovy
int pick(int a):
  return a

int pick(bool a):
  return 1

int value = pick
```

See [ERR-errAmbiguousFunctionReference](../errors/errAmbiguousFunctionReference.md#ERR-errAmbiguousFunctionReference).

## Calls through function values

A function value is a normal variable with a function type.

<!-- expect-errors: OK -->
```kovy
int twice(int a):
  return a * 2

int apply(int(int) fn, int value):
  return fn(value)

int result = apply(twice, 21)
```

The parameter `int(int) fn` is a function type. The argument `twice` is
selected by the expected type. Calls through the value use the ordinary call
path, not the global overload table.

## Forward declarations

A bodyless declaration at global scope is a forward. It must be completed by a
later definition with the same parameter types, return type, and parameter
names.

<!-- expect-errors: OK -->
```kovy
int add(int a, int b)

int add(int a, int b):
  return a + b

int result = add(2, 3)
```

A forward with no definition is reported at `finalize` as
`ERR-errUnresolvedForward`. A nested bodyless function is
`ERR-errForwardOutsideGlobal`.

## What is rejected

Default parameter values are parsed but forbidden:

<!-- expect-errors: errDefaultForbidden -->
```kovy
int add(int a = 1, int b):
  return a + b
```

Two declarations with the same parameter types and the same return type are a
redefinition:

<!-- expect-errors: errFuncRedefinition -->
```kovy
int add(int a):
  return a

int add(int a):
  return a
```

Same parameter types with a different return type are
`ERR-errOverloadByReturnType`. A definition that fails to complete a forward
with matching parameter types is `ERR-errFuncSignatureMismatch`. There are no
named arguments and no variadic functions.

## Next steps

- [Overload rules](../language/overloads.md#SEM-OVL-RESOLUTION)
- [Function semantics](../language/functions.md#KOVY-FUNCTIONS)
- [Pointers and allocation](pointers-alloc.md#KOVY-GUIDE-POINTERS)