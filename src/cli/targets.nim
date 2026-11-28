## Curated build-target aliases and raw Nim target flags.

import std/strutils

type
  BuildTarget* = object
    os*: string
    cpu*: string
    cc*: string

  TargetError* = object of CatchableError

const KnownTargets* = [
  "host",
  "linux-amd64", "linux-arm64", "linux-arm32", "linux-i386",
  "windows-amd64", "windows-i386",
  "macos-amd64", "macos-arm64",
  "freebsd-amd64"
]

proc targetOsCpu(name: string): tuple[os, cpu: string] =
  case name
  of "host":
    ("", "")
  of "linux-amd64":
    ("linux", "amd64")
  of "linux-arm64":
    ("linux", "arm64")
  of "linux-arm32":
    ("linux", "arm")
  of "linux-i386":
    ("linux", "i386")
  of "windows-amd64":
    ("windows", "amd64")
  of "windows-i386":
    ("windows", "i386")
  of "macos-amd64":
    ("macosx", "amd64")
  of "macos-arm64":
    ("macosx", "arm64")
  of "freebsd-amd64":
    ("freebsd", "amd64")
  else:
    raise newException(TargetError,
      "unknown target '" & name & "'; known targets: " &
      KnownTargets.join(", "))

proc resolveTarget*(name, os, cpu, cc: string): BuildTarget =
  ## Resolves a curated `--target` alias and applies raw `--os/--cpu/--cc`
  ## overrides.
  if name.len == 0 or name == "host":
    result = BuildTarget()
  else:
    let (targetOs, targetCpu) = targetOsCpu(name)
    result = BuildTarget(os: targetOs, cpu: targetCpu)

  if os.len > 0:
    result.os = os
  if cpu.len > 0:
    result.cpu = cpu
  if cc.len > 0:
    result.cc = cc