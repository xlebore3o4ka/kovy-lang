# ERR-errNonConcreteType

<!-- doc-id: ERR-errNonConcreteType -->
<!-- kind: errNonConcreteType -->
<!-- status: emitted -->
<!-- phase: nimgen -->

<a id="ERR-errNonConcreteType"></a>
## Message

Locale key: `errNonConcreteType`.

```text
Type @c0 is not concrete
```

| Placeholder | Meaning |
|---|---|
| `@c0` | the pointer type that directly contains `void`, via `Type.toStr` |

No addinfo.

## Emitters

- `Nimgen.nimType`, `typePtr` branch: the immediate pointee type is
  `typeVoid`. The function reports the error and returns Nim `pointer` so
  generation can continue.
- The same branch can run several times for one source program because
  `nimType` is called for declarations, function parameters and returns,
  allocation element types, pointer/array casts, and nested pointee types.

Sema does not reject `void*`: `typeVoid` is a valid pointer pointee there. This
is the one diagnostic that appears only after lexing, parsing, sema, and
`finalize` all succeed.

## Triggers

<a id="TRG-errNonConcreteType-declaration"></a>
### TRG-errNonConcreteType-declaration

<!-- expect-errors: errNonConcreteType -->
```kovy
void* p
```

The declaration type is `void*`. The declaration needs no initializer.

<a id="TRG-errNonConcreteType-parameter"></a>
### TRG-errNonConcreteType-parameter

<!-- expect-errors: errNonConcreteType -->
```kovy
void f(void* p):
  int x = 1
```

The function parameter type contains `void*`.

<a id="TRG-errNonConcreteType-return-and-parameter"></a>
### TRG-errNonConcreteType-return-and-parameter

<!-- expect-errors: errNonConcreteType, errNonConcreteType -->
```kovy
void* f(void* p):
  return p
```

Sema accepts both the parameter type and the matching return type. Nimgen
reports one error for each occurrence, in emission order: parameter first, then
return.

<a id="TRG-errNonConcreteType-double-pointer"></a>
### TRG-errNonConcreteType-double-pointer

<!-- expect-errors: errNonConcreteType -->
```kovy
void** p
```

Only the inner `void*` is non-concrete. The outer pointer is emitted as
`ptr pointer`. The message names `void*`, not `void**`.

<a id="TRG-errNonConcreteType-multiple-declarations"></a>
### TRG-errNonConcreteType-multiple-declarations

<!-- expect-errors: errNonConcreteType, errNonConcreteType -->
```kovy
void* a
void* b
```

There is no deduplication; each emission site reports again.

<a id="TRG-errNonConcreteType-function-type"></a>
### TRG-errNonConcreteType-function-type

<!-- expect-errors: errNonConcreteType -->
```kovy
void( void* ) f
```

A function type whose argument is `void*` also reaches the pointer branch when
the function type is emitted.

## Near misses

- `int*`, `bool*`, `T**`, function pointers, and pointers to function types
  are concrete.
- `alloc 1 of void` is rejected in sema as `ERR-errAllocVoid`; nimgen is not
  reached.
- `void* p = alloc 1 of int` is rejected in sema as `ERR-errDoesNotFit`
  because `int*` does not fit `void*`; nimgen is not reached.
- `void* p = [1] of void` is `ERR-errAllocVoid`.
- Dereferencing a `void*` yields `void`; using that value where a concrete type
  is required can produce a sema fit error before code generation.

## Cascades

`nimType` returns Nim `pointer` for the rejected inner type, continuing
generation. The error is attached to the token that triggered the type
emission, which can be a declaration name, parameter name, or array/alloc
token. Because the test driver only runs nimgen when earlier stages are clean,
this error is always the only phase in which these programs fail. Generated
source may still be produced, but callers must not use it when the context has
errors.

## Tests

- `tests/tPtr.nim`: `void*` rejection in nimgen
- `tests/tPtr.nim`: nested `void**` emission

## Related

- [INT-NIMGEN-NONCONCRETE](../internals/nimgen.md#INT-NIMGEN-NONCONCRETE)
- [INT-NIMGEN-TYPES](../internals/nimgen.md#INT-NIMGEN-TYPES)
- [SEM-TYPE-VOID](../language/types.md#SEM-TYPE-VOID)
- [ERR-errAllocVoid](errAllocVoid.md#ERR-errAllocVoid)