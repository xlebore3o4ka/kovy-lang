import std/[os, strutils]

type
  LocaleError* = object of CatchableError

proc localeFileName(name: string): string =
  if name.endsWith(".json"): name else: name & ".json"

proc localeCandidates(name: string): seq[string] =
  var directories: seq[string]

  let fromEnv = getEnv("KOVY_LOCALE_DIR")
  if fromEnv.len > 0:
    directories.add fromEnv

  # Running from the repository: bin/../src/error_locales.
  directories.add getAppDir() / ".." / "src" / "error_locales"
  # Installed layout: locales next to the binary.
  directories.add getAppDir() / "error_locales"
  # Last-resort compile-time path for development and test binaries.
  directories.add currentSourcePath().parentDir().parentDir() / "error_locales"

  let fileName = localeFileName(name)
  var seen: seq[string]
  for directory in directories:
    let candidate = directory / fileName
    if fileExists(candidate) and candidate notin seen:
      result.add candidate
      seen.add candidate

proc resolveLocalePath*(name, path: string): string =
  if path.len > 0:
    if not fileExists(path):
      raise newException(LocaleError, "locale file not found: " & path)
    return path

  let candidates = localeCandidates(name)
  if candidates.len == 0:
    raise newException(LocaleError,
      "locale '" & name & "' not found in error_locales; " &
      "use --locale-path <path> or set KOVY_LOCALE_DIR")
  return candidates[0]