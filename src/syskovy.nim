## Runtime helpers for generated Kovy programs.

import std/macros

proc `+`*[T](p: ptr T, n: int): ptr T =
  cast[ptr T](cast[int](p) + n * sizeof(T))

proc `+`*[T](n: int, p: ptr T): ptr T =
  cast[ptr T](cast[int](p) + n * sizeof(T))

proc `-`*[T](p: ptr T, n: int): ptr T =
  cast[ptr T](cast[int](p) - n * sizeof(T))

proc `-`*[T](a, b: ptr T): int =
  (cast[int](a) - cast[int](b)) div sizeof(T)

when defined(vcc):
  proc kovyAllocaC(size: csize_t): pointer
    {.importc: "_alloca", header: "<malloc.h>".}
elif defined(gcc) or defined(clang):
  proc kovyAllocaC(size: csize_t): pointer
    {.importc: "__builtin_alloca", header: "<alloca.h>".}
else:
  proc kovyAllocaC(size: csize_t): pointer
    {.importc: "alloca", header: "<alloca.h>".}

template kovyAlloca*(size: int): pointer =
  kovyAllocaC(csize_t(size))

template kovyAllocaZeroed*(size: int): pointer =
  ## Like `kovyAlloca`, but zeroes the memory. Nim function values are
  ## closures, and ARC/ORC touches the previous value when assigning into a
  ## slot; uninitialized stack memory can contain garbage pointers.
  block:
    let kovyZeroSize = size
    let kovyZeroPtr = kovyAlloca(kovyZeroSize)
    zeroMem(kovyZeroPtr, kovyZeroSize)
    kovyZeroPtr

macro kovyArrayLit*(count: static int, T: untyped,
                    values: varargs[untyped]): untyped =
  ## Allocates storage for an array literal and returns a pointer to its first
  ## element. The storage is zeroed because function values are closures and
  ## ARC/ORC reads the old slot value when assigning into an array of them.
  ##
  ## Elements are assigned one by one through a typed slot instead of being
  ## passed as an array literal: Nim only performs closure conversion for a
  ## top-level `proc` when it is assigned to a `proc` value, not inside a plain
  ## array literal.
  let storage = genSym(nskLet, "kovyArrayStorage")
  let n = newLit(count)
  result = newStmtList()

  result.add quote do:
    let `storage` =
      cast[ptr array[`n`, `T`]](kovyAllocaZeroed(sizeof(array[`n`, `T`])))

  for i, value in values:
    let index = newLit(i)
    result.add quote do:
      `storage`[][`index`] = `value`

  result.add quote do:
    cast[ptr `T`](`storage`)

  result = newBlockStmt(result)