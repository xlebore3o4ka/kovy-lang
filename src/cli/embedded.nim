## Source files embedded into the `kovy` binary at compile time.

import std/os

## Runtime helpers copied next to every `emit` output file.
const SyskovySource* = staticRead(
  currentSourcePath().parentDir().parentDir() / "syskovy.nim")