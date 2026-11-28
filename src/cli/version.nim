import std/[os, strutils]

const NimblePkgVersion {.strdefine.} = ""

proc versionFromNimble(content: string): string {.compileTime.} =
  for line in content.splitLines():
    let eq = line.find('=')
    if eq < 0:
      continue
    if line[0 ..< eq].strip() != "version":
      continue
    return line[eq + 1 .. ^1].strip(chars = {' ', '\t', '"', '\''})
  return "0.0.0-dev"

## The package version, taken from the Nimble build define when the binary is
## built with `nimble`. A plain `nim c` build falls back to the `.nimble` file
## in the source tree, then to a development marker.
const KovyVersion* =
  when NimblePkgVersion.len > 0:
    NimblePkgVersion
  else:
    versionFromNimble(staticRead(
      currentSourcePath().parentDir().parentDir().parentDir() / "kovylang.nimble"))