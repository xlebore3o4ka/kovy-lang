"""Kovy diagnostics for Sublime Text.

The plugin is deliberately a thin client around the compiler front-end:

    kovy check --json - --name <current file>

It renders the JSON report as squiggly regions, gutter marks, a status-bar
summary, and an output panel.  Semantic features such as go-to-definition can
be added on top of the same command later.
"""

import json
import os
import shutil
import subprocess
import threading
import time

import sublime
import sublime_plugin


SETTINGS_FILE = "Kovy.sublime-settings"
REGION_KEY = "kovy_diagnostics"
STATUS_KEY = "kovy"
PANEL_NAME = "kovy_diagnostics"

_STATE = {}
_STATE_LOCK = threading.Lock()


def _setting(view, key, default=None):
    """Return a view/project override, then the package setting."""
    if view is not None:
        try:
            if view.settings().has(key):
                return view.settings().get(key)
        except Exception:
            pass
    return sublime.load_settings(SETTINGS_FILE).get(key, default)


def _is_kovy(view):
    try:
        if view.match_selector(0, "source.kovy"):
            return True
    except Exception:
        pass
    name = view.file_name() or ""
    return name.lower().endswith(".kovy")


def _expand_path(value):
    if not value:
        return ""
    return os.path.expanduser(os.path.expandvars(str(value)))


def _is_executable(path):
    if not os.path.isfile(path):
        return False
    if os.name == "nt":
        return True
    return os.access(path, os.X_OK)


def _search_roots(view):
    roots = []
    file_name = view.file_name()
    if file_name:
        roots.append(os.path.dirname(file_name))
    window = view.window()
    if window is not None:
        try:
            roots.extend(window.folders())
        except Exception:
            pass
    # A source checkout next to the package is convenient during development.
    package_dir = os.path.dirname(os.path.realpath(__file__))
    roots.append(os.path.join(package_dir, "..", "..", ".."))

    result = []
    seen = set()
    for root in roots:
        if not root:
            continue
        root = os.path.abspath(root)
        if root not in seen:
            seen.add(root)
            result.append(root)
    return result


def _find_kovy(view):
    candidates = []
    configured = _setting(view, "kovy_executable", "kovy")
    if configured:
        candidates.append(configured)
    env = os.environ.get("KOVY_BIN")
    if env:
        candidates.append(env)
    candidates.append("kovy")

    for candidate in candidates:
        path = _expand_path(candidate)
        if not path:
            continue
        has_separator = os.sep in path or (os.altsep and os.altsep in path)
        if os.path.isabs(path) or has_separator:
            if not os.path.isabs(path):
                roots = _search_roots(view)
                if not roots:
                    continue
                path = os.path.join(roots[0], path)
            path = os.path.abspath(path)
            if _is_executable(path):
                return path
        else:
            found = shutil.which(path)
            if found:
                return found

    # Running from a source checkout: find the sibling bin/kovy.
    names = ["kovy.exe", "kovy"] if os.name == "nt" else ["kovy", "kovy.exe"]
    for root in _search_roots(view):
        current = root
        for _ in range(6):
            for name in names:
                candidate = os.path.join(current, "bin", name)
                if _is_executable(candidate):
                    return candidate
            parent = os.path.dirname(current)
            if parent == current:
                break
            current = parent
    return None


def _build_args(view, executable, name):
    args = [executable, "check", "--json"]

    locale_path = _expand_path(_setting(view, "kovy_locale_path", ""))
    locale = str(_setting(view, "kovy_locale", "") or "")
    if locale_path:
        args.extend(["--locale-path", locale_path])
    elif locale:
        args.extend(["--locale", locale])

    if _setting(view, "kovy_check_no_nimgen", False):
        args.append("--no-nimgen")

    extra = _setting(view, "kovy_extra_args", [])
    if isinstance(extra, (list, tuple)):
        args.extend(str(item) for item in extra)

    args.extend(["--name", name, "-"])
    return args


def _startupinfo():
    if os.name != "nt":
        return {}
    info = subprocess.STARTUPINFO()
    info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    return {"startupinfo": info, "creationflags": subprocess.CREATE_NO_WINDOW}


def _parse_report(stdout):
    report = json.loads(stdout)
    if not isinstance(report, dict):
        raise ValueError("report is not a JSON object")
    if report.get("schemaVersion") != 1:
        raise ValueError("unsupported schemaVersion: %r" % (report.get("schemaVersion"),))
    diagnostics = report.get("diagnostics")
    if not isinstance(diagnostics, list):
        raise ValueError("diagnostics is not an array")
    if not all(isinstance(item, dict) for item in diagnostics):
        raise ValueError("diagnostics contains a non-object entry")
    return diagnostics


def _run_check(view, generation, text, name, cwd, args, timeout_ms):
    started = time.time()
    try:
        completed = subprocess.run(
            args,
            input=text.encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=cwd,
            timeout=max(1.0, timeout_ms / 1000.0),
            **_startupinfo()
        )
        stdout = completed.stdout.decode("utf-8", "replace")
        stderr = completed.stderr.decode("utf-8", "replace")
        elapsed = int((time.time() - started) * 1000)

        if completed.returncode in (0, 1):
            try:
                diagnostics = _parse_report(stdout)
                result = {
                    "ok": True,
                    "diagnostics": diagnostics,
                    "stderr": stderr,
                    "elapsed_ms": elapsed,
                }
            except Exception as error:
                result = {
                    "ok": False,
                    "error": "Invalid JSON from kovy: %s\n%s\n%s" % (
                        error,
                        stdout.strip()[:2000],
                        stderr.strip()[:2000],
                    ),
                }
        else:
            result = {
                "ok": False,
                "error": stderr.strip() or (
                    "kovy check exited with status %d" % completed.returncode
                ),
            }
    except FileNotFoundError:
        result = {
            "ok": False,
            "error": "Could not start kovy: %s" % args[0],
        }
    except subprocess.TimeoutExpired:
        result = {
            "ok": False,
            "error": "kovy check timed out after %d ms" % timeout_ms,
        }
    except Exception as error:
        result = {
            "ok": False,
            "error": "kovy check failed: %s" % error,
        }

    sublime.set_timeout(
        lambda: _apply_result(view, generation, result),
        0,
    )


def _begin_check(view, generation):
    if not view.is_valid():
        return
    state = _STATE.get(view.id())
    if not state or state.get("generation") != generation:
        return
    if view.is_loading():
        _schedule_check(view, 120)
        return

    text = view.substr(sublime.Region(0, view.size()))
    file_name = view.file_name()
    name = file_name or "buffer.kovy"
    cwd = None
    if file_name:
        directory = os.path.dirname(file_name)
        if os.path.isdir(directory):
            cwd = directory

    executable = _find_kovy(view)
    if not executable:
        _apply_result(
            view,
            generation,
            {
                "ok": False,
                "error": (
                    "Kovy executable was not found. Set \"kovy_executable\" in "
                    "Kovy.sublime-settings or the KOVY_BIN environment variable."
                ),
            },
        )
        return

    args = _build_args(view, executable, name)
    timeout_ms = int(_setting(view, "kovy_check_timeout_ms", 15000) or 15000)
    state["running"] = True
    sublime.set_timeout_async(
        lambda: _run_check(view, generation, text, name, cwd, args, timeout_ms),
        0,
    )


def _schedule_check(view, delay_ms=0):
    if not _is_kovy(view):
        return

    with _STATE_LOCK:
        state = _STATE.setdefault(view.id(), {})
        state["generation"] = state.get("generation", 0) + 1
        generation = state["generation"]
        timer = state.pop("timer", None)
        if timer is not None:
            timer.cancel()
        timer = threading.Timer(
            max(0, delay_ms) / 1000.0,
            lambda: sublime.set_timeout(lambda: _begin_check(view, generation), 0),
        )
        timer.daemon = True
        state["timer"] = timer
        timer.start()


def _region_for_diagnostic(view, text, diagnostic):
    lines = text.splitlines()
    try:
        line_index = max(0, int(diagnostic.get("line", 1)) - 1)
        column = max(1, int(diagnostic.get("column", 1)))
        length = max(1, int(diagnostic.get("length", 1) or 1))
    except (TypeError, ValueError):
        line_index, column, length = 0, 1, 1

    if line_index >= len(lines):
        point = view.size()
        return sublime.Region(point, point)

    line = lines[line_index]
    raw = line.encode("utf-8")
    start_byte = min(column - 1, len(raw))
    end_byte = min(start_byte + length, len(raw))
    if end_byte <= start_byte and raw:
        end_byte = min(start_byte + 1, len(raw))

    start_char = len(raw[:start_byte].decode("utf-8", "replace"))
    end_char = len(raw[:end_byte].decode("utf-8", "replace"))
    line_length = len(line)
    start_char = min(start_char, line_length)
    if line_length:
        end_char = min(max(end_char, start_char + 1), line_length)
    else:
        end_char = start_char

    return sublime.Region(
        view.text_point(line_index, start_char),
        view.text_point(line_index, end_char),
    )


def _status_text(diagnostic):
    kind = diagnostic.get("kind") or "error"
    message = diagnostic.get("message") or ""
    return "Kovy: %s: %s" % (kind, message)


def _summary(count):
    if count == 0:
        return "Kovy: no diagnostics"
    if count == 1:
        return "Kovy: 1 error"
    return "Kovy: %d errors" % count


def _apply_result(view, generation, result):
    if not view.is_valid():
        return
    state = _STATE.get(view.id())
    if not state or state.get("generation") != generation:
        return
    state["running"] = False
    state["result"] = result

    if not result.get("ok"):
        view.erase_regions(REGION_KEY)
        view.set_status(STATUS_KEY, "Kovy: check failed")
        state["regions"] = []
        state["messages"] = []
        _update_panel(view, result)
        return

    diagnostics = result.get("diagnostics") or []
    text = view.substr(sublime.Region(0, view.size()))
    regions = []
    messages = []
    for diagnostic in diagnostics:
        try:
            region = _region_for_diagnostic(view, text, diagnostic)
        except Exception:
            continue
        regions.append(region)
        messages.append(_status_text(diagnostic))

    if regions:
        view.add_regions(
            REGION_KEY,
            regions,
            "invalid",
            "dot",
            sublime.DRAW_SQUIGGLY_UNDERLINE
            | sublime.DRAW_NO_FILL
            | sublime.DRAW_NO_OUTLINE,
        )
    else:
        view.erase_regions(REGION_KEY)

    state["regions"] = regions
    state["messages"] = messages
    if diagnostics:
        view.set_status(STATUS_KEY, _summary(len(diagnostics)))
    else:
        view.erase_status(STATUS_KEY)

    _update_status_for_cursor(view)
    _update_panel(view, result)


def _update_status_for_cursor(view):
    state = _STATE.get(view.id())
    if not state or not state.get("result") or not state["result"].get("ok"):
        return
    regions = state.get("regions") or []
    messages = state.get("messages") or []
    if not regions:
        return
    selection = view.sel()
    if not selection:
        return
    point = selection[0].b
    for region, message in zip(regions, messages):
        if region.begin() <= point <= region.end():
            view.set_status(STATUS_KEY, message)
            return
    count = len(regions)
    view.set_status(STATUS_KEY, _summary(count))


def _format_result(view, result):
    name = view.file_name() or "buffer.kovy"
    if not result:
        return (
            "Kovy: no diagnostics recorded yet.\n\n"
            "Run \"Kovy: Check File\" to invoke kovy check --json.\n"
        )
    if not result.get("ok"):
        return "Kovy: check failed\n\n%s\n" % (result.get("error") or "")

    diagnostics = result.get("diagnostics") or []
    elapsed = result.get("elapsed_ms")
    header = _summary(len(diagnostics))
    if elapsed is not None:
        header += " (%d ms)" % elapsed
    lines = [header, ""]
    if not diagnostics:
        lines.append("No diagnostics. The file passed the Kovy front-end.")
        lines.append("")
        return "\n".join(lines)

    for diagnostic in diagnostics:
        kind = diagnostic.get("kind") or "error"
        phase = diagnostic.get("phase") or "unknown"
        line = diagnostic.get("line", 0)
        column = diagnostic.get("column", 0)
        length = max(1, int(diagnostic.get("length", 1) or 1))
        message = diagnostic.get("message") or ""
        lines.append(
            "%s:%s:%s: error [%s/%s] %s"
            % (name, line, column, phase, kind, message)
        )

        addinfo = (diagnostic.get("addinfo") or "").strip()
        if addinfo:
            for addline in addinfo.splitlines():
                lines.append("  " + addline)

        source_line = diagnostic.get("sourceLine") or ""
        if source_line:
            lines.append("  | " + source_line)
            marker = "^" if length < 2 else "~"
            lines.append("  | " + " " * max(0, column - 1) + marker * length)
        lines.append("")

    return "\n".join(lines)


class KovyPanelReplaceCommand(sublime_plugin.TextCommand):
    def run(self, edit, text):
        self.view.replace(edit, sublime.Region(0, self.view.size()), text)


def _write_panel(panel, text):
    panel.set_read_only(False)
    panel.run_command("kovy_panel_replace", {"text": text})
    panel.set_read_only(True)


def _update_panel(view, result):
    window = view.window()
    if window is None:
        return
    panel = window.find_output_panel(PANEL_NAME)
    if panel is not None:
        _write_panel(panel, _format_result(view, result))


def _show_panel(window, view):
    panel = window.create_output_panel(PANEL_NAME)
    panel.settings().set("word_wrap", False)
    panel.settings().set("gutter", False)
    panel.settings().set("line_numbers", False)
    panel.settings().set("scroll_past_end", False)
    state = _STATE.get(view.id(), {})
    _write_panel(panel, _format_result(view, state.get("result")))
    window.run_command("show_panel", {"panel": "output." + PANEL_NAME})


class KovyCheckCommand(sublime_plugin.TextCommand):
    """Run kovy check for the active view and show diagnostics."""

    def run(self, edit):
        if not _is_kovy(self.view):
            sublime.status_message("Kovy: the active view is not Kovy source")
            return
        _schedule_check(self.view, 0)


class KovyShowDiagnosticsCommand(sublime_plugin.WindowCommand):
    """Show the diagnostic panel and refresh it in the background."""

    def run(self):
        view = self.window.active_view()
        if view is None:
            return
        _show_panel(self.window, view)
        if _is_kovy(view):
            _schedule_check(view, 0)


class KovyClearDiagnosticsCommand(sublime_plugin.TextCommand):
    """Remove the current view's diagnostic regions and status message."""

    def run(self, edit):
        view = self.view
        view.erase_regions(REGION_KEY)
        view.erase_status(STATUS_KEY)
        with _STATE_LOCK:
            state = _STATE.setdefault(view.id(), {})
            state["generation"] = state.get("generation", 0) + 1
            timer = state.pop("timer", None)
            if timer is not None:
                timer.cancel()
            # Mark the view as checked-clean so a later activation does not
            # immediately re-run the check the user just cleared.
            state["result"] = {"ok": True, "diagnostics": []}
            state["regions"] = []
            state["messages"] = []


class KovyEventListener(sublime_plugin.EventListener):
    def on_load_async(self, view):
        if _setting(view, "kovy_check_on_open", True) and _is_kovy(view):
            _schedule_check(view, 120)

    def on_activated_async(self, view):
        _update_status_for_cursor(view)
        if not _setting(view, "kovy_check_on_open", True) or not _is_kovy(view):
            return
        state = _STATE.get(view.id())
        if not state or state.get("result") is None:
            _schedule_check(view, 120)

    def on_post_save_async(self, view):
        if _setting(view, "kovy_check_on_save", True) and _is_kovy(view):
            _schedule_check(view, 0)

    def on_modified_async(self, view):
        if not _setting(view, "kovy_check_on_type", False):
            return
        if not _is_kovy(view) or view.is_loading():
            return
        delay = int(_setting(view, "kovy_check_delay_ms", 500) or 500)
        _schedule_check(view, delay)

    def on_selection_modified_async(self, view):
        _update_status_for_cursor(view)

    def on_close(self, view):
        with _STATE_LOCK:
            state = _STATE.pop(view.id(), None)
        if state is not None:
            timer = state.get("timer")
            if timer is not None:
                timer.cancel()


def plugin_unloaded():
    with _STATE_LOCK:
        states = list(_STATE.values())
        _STATE.clear()
    for state in states:
        timer = state.get("timer")
        if timer is not None:
            timer.cancel()