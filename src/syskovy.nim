## Runtime helpers for generated Kovy programs.

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