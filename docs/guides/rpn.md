# RPN interpreter walkthrough

<!-- doc-id: KOVY-GUIDE-RPN -->
<!-- status: current -->

<a id="KOVY-GUIDE-RPN"></a>
`examples/rpn.kovy` is the largest complete program in the repository. It is a
stack-machine interpreter for a small reverse-Polish bytecode. It exercises
global state, mutable parameters, pointers, pointer arithmetic, arrays,
function pointers, overloads, and dispatch.

<a id="EX-RPN-PROGRAM"></a>
## The complete program

<!-- expect-errors: OK -->
```kovy
int PUSH = 1, ADD = 2, SUB = 3, MUL = 4, DIV = 5, NEG = 6, HALT = 0
int TOTAL_INST_COUNT = 7

void wr(int* mut a, int mut i, int b):
  #(a + i) = b
  i = i + 1

void wr(int* mut a, int mut i, int b, int c):
  #(a + i) = b
  i = i + 1
  #(a + i) = c
  i = i + 1

int mut bytecodeSize
int* mut bytecode = alloc (bytecodeSize = 256) of int

int* mut stack = alloc 256 of int
int mut pc, sp

void(mut int*, mut int*, mut int, mut int)* mut dispatcher = alloc TOTAL_INST_COUNT of void(mut int*, mut int*, mut int, mut int)

void push(int* mut stack, int mut sp, int v):
  #(stack + sp) = v
  sp = sp + 1

int pop(int* mut stack, int mut sp):
  sp = sp - 1
  return #(stack + sp)

void handlePUSH(int* mut bytecode, stack, int mut pc, sp):
  int val = #(bytecode + pc)
  pc = pc + 1
  push(stack, sp, val)
#(dispatcher + PUSH) = handlePUSH

void handleADD(int* mut bytecode, stack, int mut pc, sp):
  int b = pop(stack, sp)
  int a = pop(stack, sp)
  push(stack, sp, a + b)
#(dispatcher + ADD) = handleADD

void handleSUB(int* mut bytecode, stack, int mut pc, sp):
  int b = pop(stack, sp)
  int a = pop(stack, sp)
  push(stack, sp, a - b)
#(dispatcher + SUB) = handleSUB

void handleMUL(int* mut bytecode, stack, int mut pc, sp):
  int b = pop(stack, sp)
  int a = pop(stack, sp)
  push(stack, sp, a * b)
#(dispatcher + MUL) = handleMUL

void handleDIV(int* mut bytecode, stack, int mut pc, sp):
  int b = pop(stack, sp)
  int a = pop(stack, sp)
  push(stack, sp, a / b)
#(dispatcher + DIV) = handleDIV

void handleNEG(int* mut bytecode, stack, int mut pc, sp):
  int a = pop(stack, sp)
  push(stack, sp, -a)
#(dispatcher + NEG) = handleNEG

void handleHALT(int* mut bytecode, stack, int mut pc, sp):
  pc = bytecodeSize
#(dispatcher + HALT) = handleHALT

void step(int* mut bytecode, stack, int mut pc, sp):
  int inst = #(bytecode + pc)
  pc = pc + 1
  (#(dispatcher + inst))(bytecode, stack, pc, sp)

int mut i = 0
wr(bytecode, i, PUSH, 10)
wr(bytecode, i, PUSH, 20)
wr(bytecode, i, PUSH, 30)
wr(bytecode, i, ADD)
wr(bytecode, i, MUL)
wr(bytecode, i, PUSH, 1)
wr(bytecode, i, NEG)
wr(bytecode, i, MUL)
wr(bytecode, i, PUSH, 1200)
wr(bytecode, i, ADD)
wr(bytecode, i, HALT)

while pc < i:
  step(bytecode, stack, pc, sp)

int a = #stack
```

<a id="EX-RPN-STATE"></a>
## Global state

The first group defines opcodes and the dispatcher size. All are immutable
`int` globals:

```text
int PUSH = 1, ADD = 2, SUB = 3, MUL = 4, DIV = 5, NEG = 6, HALT = 0
int TOTAL_INST_COUNT = 7
```

`bytecode`, `stack`, and `dispatcher` are mutable pointers allocated once at
global scope. Allocation is allowed here because the global initializers are
not inside a loop.

The count expression `(bytecodeSize = 256)` is an assignment expression. It
writes `bytecodeSize` and yields the mutable `int` value, which is accepted as
the element count.

`int mut pc, sp` declares two mutable integers in one group. They are the
program counter and stack pointer.

<a id="EX-RPN-DISPATCH-TYPE"></a>
## The dispatcher type

```text
void(mut int*, mut int*, mut int, mut int)* mut dispatcher
```

Read this from the inside out:

- `void(...)` is a function type returning `void`.
- Its four parameters are `mut int*`, `mut int*`, `mut int`, and `mut int`.
- The last `*` makes a pointer to that function type.
- The trailing `mut` makes the pointer symbol itself mutable.

The dispatcher is an array of seven such function pointers. Each handler is
installed with `#(dispatcher + OPCODE) = handlerName`.

<a id="EX-RPN-STACK"></a>
## Stack operations

`push` writes at `stack + sp` and increments `sp`. `pop` decrements `sp` and
returns the element at the new position.

```text
void push(int* mut stack, int mut sp, int v):
  #(stack + sp) = v
  sp = sp + 1

int pop(int* mut stack, int mut sp):
  sp = sp - 1
  return #(stack + sp)
```

`sp` is a mutable parameter, so the caller's variable is updated by the
generated `var int` parameter. The pointer `stack` is also mutable, which is
what grants write permission to `#(stack + sp)`.

<a id="EX-RPN-HANDLERS"></a>
## Handlers

Each handler has the same four parameters, matching the dispatcher's function
type. `handlePUSH` reads the next bytecode word and advances `pc`:

```text
int val = #(bytecode + pc)
pc = pc + 1
push(stack, sp, val)
```

Binary handlers pop the right operand first, then the left, and push the
result. `handleNEG` pops one value and pushes its negation. `handleHALT` sets
`pc` beyond the program end so the driver loop stops.

Each handler is installed immediately after its definition:

```text
#(dispatcher + ADD) = handleADD
```

Because the handler name has exactly one overload, the expected function
pointer type is enough to resolve it without ambiguity.

<a id="EX-RPN-STEP"></a>
## The step function

```text
int inst = #(bytecode + pc)
pc = pc + 1
(#(dispatcher + inst))(bytecode, stack, pc, sp)
```

The first two lines fetch the opcode and advance `pc`. The third line reads
the function pointer from the dispatcher and calls it. The parentheses around
`#(dispatcher + inst)` are required: without them, the postfix call would bind
inside the dereference and the program would try to call the pointer first.

The call passes `bytecode`, `stack`, `pc`, and `sp` in order. The first two are
mutable pointers; the last two are mutable `int` parameters.

<a id="EX-RPN-PROGRAM-DATA"></a>
## Encoding a program

The global driver uses the two `wr` overloads to write bytecode. The
two-argument form writes one word; the four-argument form writes two:

```text
wr(bytecode, i, PUSH, 10)
```

Here `i` is the write cursor. The overload set is resolved by arity and
parameter types. The program encoded is:

```text
PUSH 10
PUSH 20
PUSH 30
ADD
MUL
PUSH 1
NEG
MUL
PUSH 1200
ADD
HALT
```

The arithmetic is `(10 + 20) * 30 = 500`; then `500 * -1 = -500`; then
`-500 + 1200 = 700`. The final global `int a = #stack` reads the top of the
stack, which is `700`.

<a id="EX-RPN-RUN"></a>
## The driver loop

```text
while pc < i:
  step(bytecode, stack, pc, sp)

int a = #stack
```

`pc` starts at `0`, and `i` is the number of written words. Each iteration
fetches and executes one instruction. `HALT` sets `pc` to `bytecodeSize`, which
is larger than `i`, so the loop ends.

There is no output. The observable result is the value left in `stack[0]`,
read into `a`; a host program that consumes the generated Nim would inspect
that value.

## What this example teaches

- Global mutable state is declared with `mut` and initialized by expressions.
- `alloc` and array literals are allowed at global scope but not inside loops.
- Function pointers are ordinary pointer values with a function pointee type.
- Overloads resolve by arity and parameter types.
- Pointer arithmetic plus `#` is the only indexing mechanism.
- Parentheses around a dereferenced function pointer are required before a
  call.

## Related

- [Functions and overloads](functions-overloads.md#KOVY-GUIDE-FUNCTIONS)
- [Pointers and allocation](pointers-alloc.md#KOVY-GUIDE-POINTERS)
- [Arrays](arrays.md#KOVY-GUIDE-ARRAYS)
- [Function pointers](../language/pointers.md#SEM-PTR-FUNCTION)