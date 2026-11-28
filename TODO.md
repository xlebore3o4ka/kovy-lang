# TODO: QoL CLI `kovy`

Пользовательская команда: `kovy`. `kovylang` остаётся рабочим именем пакета,
отдельный пользовательский бинарник с этим именем не публикуется.

## Зафиксированные решения

- [x] Убрать команду `run`.
- [x] Диагностики: по умолчанию human, с `--json` — только JSON в stdout.
- [x] Локаль не встраивать в бинарник.
- [x] Runtime `syskovy` встраивать через `staticRead`.
- [x] Два флага локали: `--locale <name>` и `--locale-path <path>`.
- [x] `--locale` и `--locale-path` взаимоисключающие.
- [x] Локаль по умолчанию: `en`, ищется в `error_locales` компилятора.
- [x] Обязательная субкоманда; без неё — короткая подсказка и `--help`.
- [x] При ошибке использования печатать короткое сообщение, а не полный help.
- [x] `check` по умолчанию проходит до nimgen; `--no-nimgen` останавливает после sema.
- [x] JSON-схема: `schemaVersion: 1`, поля `kind`, `phase`, `severity`,
      `message`, `addinfo`, `line`, `column`, `length`, `sourceLine`.

## Этап 1. Каркас CLI + `check` (human)

- [x] Добавить `src/kovy.nim` как тонкий entry point.
- [x] Добавить `src/cli/args.nim`: разбор argv в типизированную команду.
- [x] Добавить `src/cli/input.nim`: файл/stdin/TTY, `--name`.
- [x] Добавить `src/cli/frontend.nim`: lexer → parser → sema → nimgen.
- [x] Добавить `src/cli/main.nim`: dispatch, exit codes, короткие usage-ошибки.
- [x] Обновить `kovylang.nimble`: `bin = @["kovy"]`.
- [x] Реализовать `kovy check [file|-]`.
- [x] Реализовать `--locale`, `--locale-path`, `--no-nimgen`.
- [x] Реализовать `kovy --help` и `kovy --version`.
- [x] Exit codes: 0 — чисто, 1 — диагностики, 2 — ошибка использования/локали.
- [x] Тесты: аргументы, stdin/файл, локали, usage-ошибки, `check`.
- [x] Документация: `docs/reference/cli.md`, обновить `docs/language/pipeline.md`.

## Этап 2. JSON-линтер

- [x] Добавить `--json` для `check`.
- [x] Вынести публичные `formatMessage`/`formatAddinfo` в `errors.nim`.
- [x] Реализовать JSON-рендерер с `schemaVersion: 1`.
- [x] Добавить golden-тесты схемы и экранирования.
- [x] Документировать JSON-схему.

## Этап 3. `emit nim`

- [x] Добавить `kovy emit <file> -o <out.nim>`.
- [x] Встроить `syskovy.nim` через `staticRead`.
- [x] Писать `out.nim` и `syskovy.nim` рядом.
- [x] Поддержать `-o -` для вывода только Nim в stdout.
- [x] Проверить, что сгенерированный Nim собирается через `nim c`.
- [x] Документировать `emit`.

## Этап 4. `build`

- [x] Добавить `kovy build <file>`.
- [x] Вызывать Nim через `std/osproc` с массивом аргументов.
- [x] Поддержать `--target`, `--os`, `--cpu`, `--cc`.
- [x] Поддержать `--release`, `--debug`, `--nim`, `--nimcache`.
- [x] Временная папка, очистка, `--keep-nim`.
- [x] Понятные ошибки при отсутствии Nim/toolchain.
- [x] Интеграционный тест: собрать пример и запустить бинарник.
- [x] Документировать `build` и кросс-сборку.
