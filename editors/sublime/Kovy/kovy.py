"""Kovy support for Sublime Text.

Diagnostics, hover text, and diagnostic navigation come from the LSP package
and the Kovy language server in ``editors/lsp/kovy_lsp.py``.  This module also
adds the small editor conveniences that are not part of LSP:

* a dynamic text panel with the details of the diagnostic under the caret;
* smart Enter, which adds one indentation level after a block-opening ``:``;
* a guard for the comment shortcuts, because Kovy has no comments.

The syntax highlighting and the color schemes remain useful without LSP; the
diagnostics panel and the LSP keybindings simply do nothing until a language
server session is attached.
"""

import os
import re
import shutil

import sublime
import sublime_plugin


PANEL_NAME = "kovy_diagnostics"
PANEL_PATH = "output." + PANEL_NAME
SETTINGS_FILE = "Kovy.sublime-settings"

# view id -> list of (LSP Diagnostic, sublime.Region)
_DIAGNOSTICS = {}

_LSP_PLUGIN_CLASS = None
_LSP_IMPORT_ATTEMPTS = 0


# ---------------------------------------------------------------------------
# Small helpers


def _setting(view, key, default=None):
    value = view.settings().get(key)
    return default if value is None else value


def _is_kovy(view):
    return bool(view) and view.match_selector(0, "source.kovy")


def _panel_mode(view):
    mode = str(_setting(view, "kovy_details_panel", "manual")).strip().lower()
    if mode not in ("auto", "manual", "off"):
        return "manual"
    return mode


def _indent_unit(view):
    tab_size = _setting(view, "tab_size", 2)
    try:
        tab_size = max(1, int(tab_size))
    except (TypeError, ValueError):
        tab_size = 2
    if _setting(view, "translate_tabs_to_spaces", True):
        return " " * tab_size
    return "\t"


def _clamped_int(value, default=0, minimum=0):
    try:
        return max(minimum, int(value))
    except (TypeError, ValueError):
        return default


def _markup_text(value):
    if isinstance(value, dict):
        return str(value.get("value") or "")
    return "" if value is None else str(value)


def _diagnostic_data(diagnostic):
    data = diagnostic.get("data") if isinstance(diagnostic, dict) else None
    return data if isinstance(data, dict) else {}


def _diagnostic_message(diagnostic):
    data = _diagnostic_data(diagnostic)
    if data.get("message"):
        return _markup_text(data.get("message"))
    return _markup_text(diagnostic.get("message"))


def _diagnostic_addinfo(diagnostic):
    data = _diagnostic_data(diagnostic)
    value = data.get("addinfo")
    return _markup_text(value).strip()


def _diagnostic_under_point(view, point):
    entries = _DIAGNOSTICS.get(view.id()) or []
    selected = []
    for diagnostic, region in entries:
        if region.begin() <= point <= region.end():
            selected.append(diagnostic)
    return selected


def _format_diagnostic(view, diagnostic):
    data = _diagnostic_data(diagnostic)
    path = view.file_name() or "buffer.kovy"
    line = _clamped_int(data.get("line"), 0)
    column = _clamped_int(data.get("column"), 0)
    length = _clamped_int(data.get("length"), 0)
    kind = data.get("kind") or diagnostic.get("code") or "error"
    phase = data.get("phase") or ""
    message = _diagnostic_message(diagnostic)
    addinfo = _diagnostic_addinfo(diagnostic)

    source_line = data.get("sourceLine")
    if source_line is None and line > 0:
        point = view.text_point(line - 1, 0)
        source_line = view.substr(view.line(point))
    source_line = "" if source_line is None else str(source_line)

    marker = "^" if length < 2 else "~"
    marker = marker * max(1, length)
    header = "%s(%d,%d) [%s]" % (path, column, line, kind)
    if phase:
        header += " " + phase

    lines = [header, "  |", "  | " + source_line]
    lines.append("  V " + " " * max(0, column - 1) + marker)
    lines.append(message)
    if addinfo:
        for addline in addinfo.splitlines():
            lines.append("  " + addline)
    return "\n".join(lines)


def _format_diagnostics(view, diagnostics):
    if not diagnostics:
        return (
            "No Kovy diagnostic under the caret.\n"
            "\n"
            "Move the caret over an error to see its details.\n"
            "F4 / Shift+F4 jump to the next / previous diagnostic.\n"
        )
    return "\n\n".join(_format_diagnostic(view, d) for d in diagnostics)


# ---------------------------------------------------------------------------
# Panel plumbing


def _panel_visible(window):
    return window.active_panel() == PANEL_PATH


def _write_panel(window, text):
    panel = window.find_output_panel(PANEL_NAME)
    if panel is None:
        panel = window.create_output_panel(PANEL_NAME)
        settings = panel.settings()
        settings.set("word_wrap", False)
        settings.set("gutter", False)
        settings.set("line_numbers", False)
        settings.set("scroll_past_end", False)
        settings.set("draw_white_space", "none")
        # Call create_output_panel a second time so Sublime re-reads the
        # panel settings.  This is the same pattern used by Default/exec.py.
        panel = window.create_output_panel(PANEL_NAME)
    if panel is None:
        return
    panel.set_read_only(False)
    panel.run_command("kovy_panel_replace", {"text": text})
    panel.set_read_only(True)


def _show_panel(window, view):
    if not _panel_visible(window):
        window.run_command("show_panel", {"panel": PANEL_PATH})
    if window.active_view() != view:
        window.focus_view(view)


def _hide_panel(window, view=None):
    window.run_command("hide_panel", {"panel": PANEL_PATH})
    if view is not None and window.active_view() != view:
        window.focus_view(view)


def _update_panel_for_view(view, force_show=False):
    if not view.is_valid() or not _is_kovy(view):
        return
    window = view.window()
    if window is None:
        return

    mode = _panel_mode(view)
    if not force_show and mode == "off":
        return

    selection = view.sel()
    point = selection[0].b if selection else 0
    diagnostics = _diagnostic_under_point(view, point)
    text = _format_diagnostics(view, diagnostics)

    visible = _panel_visible(window)
    if diagnostics or force_show or visible:
        _write_panel(window, text)

    if force_show:
        if not visible:
            _show_panel(window, view)
    elif diagnostics:
        if mode == "auto" and not visible:
            _show_panel(window, view)
    elif visible and mode == "auto":
        _hide_panel(window, view)


def _store_diagnostics(view, session_buffer):
    entries = list(session_buffer.diagnostics)
    _DIAGNOSTICS[view.id()] = entries
    sublime.set_timeout(lambda: _update_panel_for_view(view), 0)


class KovyPanelReplaceCommand(sublime_plugin.TextCommand):
    def run(self, edit, text=""):
        self.view.replace(edit, sublime.Region(0, self.view.size()), text)


# ---------------------------------------------------------------------------
# Commands


class KovyShowDetailsCommand(sublime_plugin.TextCommand):
    """Toggle the dynamic Kovy diagnostics panel."""

    def run(self, edit):
        if not _is_kovy(self.view):
            sublime.status_message("Kovy: the active view is not Kovy source")
            return
        window = self.view.window()
        if window is None:
            return
        if _panel_visible(window):
            _hide_panel(window, self.view)
            return
        _update_panel_for_view(self.view, force_show=True)
        _show_panel(window, self.view)


class KovyEnterCommand(sublime_plugin.TextCommand):
    """Insert a newline with Kovy-aware indentation."""

    def run(self, edit):
        if not _setting(self.view, "kovy_smart_enter", True):
            self.view.run_command("insert", {"characters": "\n"})
            return

        view = self.view
        unit = _indent_unit(view)
        selections = list(view.sel())
        view.sel().clear()
        new_points = []

        for selection in reversed(selections):
            line = view.line(selection.begin())
            prefix = view.substr(sublime.Region(line.begin(), selection.begin()))
            line_text = view.substr(line)
            indent = re.match(r"[ \t]*", line_text).group(0)

            # A block opener is the last non-whitespace character before the
            # caret.  Kovy has no comments or strings, so this is unambiguous.
            if prefix.rstrip().endswith(":"):
                indent += unit

            text = "\n" + indent
            view.replace(edit, selection, text)
            new_points.append(selection.begin() + len(text))

        for point in sorted(new_points):
            view.sel().add(sublime.Region(point, point))
        if new_points:
            view.show(min(new_points))


class KovyNoCommentsCommand(sublime_plugin.TextCommand):
    """Explain that Kovy has no comments; ``#`` is dereference."""

    def run(self, edit):
        sublime.status_message(
            "Kovy has no comments. '#' is the dereference operator, not a comment."
        )


# ---------------------------------------------------------------------------
# LSP integration


def _server_path():
    override = sublime.load_settings(SETTINGS_FILE).get("kovy_lsp_server", "")
    if override:
        return os.path.expanduser(os.path.expandvars(str(override)))
    here = os.path.dirname(os.path.realpath(__file__))
    return os.path.normpath(os.path.join(here, "..", "..", "lsp", "kovy_lsp.py"))


def _python_path():
    override = sublime.load_settings(SETTINGS_FILE).get("kovy_python", "")
    if override:
        return os.path.expanduser(os.path.expandvars(str(override)))
    for candidate in ("python3", "python"):
        found = shutil.which(candidate)
        if found:
            return found
    return ""


def _compiler_path():
    override = sublime.load_settings(SETTINGS_FILE).get("kovy_executable", "")
    if not override:
        return ""
    return os.path.expanduser(os.path.expandvars(str(override)))


def _try_register_lsp():
    global _LSP_PLUGIN_CLASS, _LSP_IMPORT_ATTEMPTS
    if _LSP_PLUGIN_CLASS is not None:
        return
    try:
        from LSP.plugin import LspPlugin
        from LSP.plugin import PluginStartError
    except Exception:
        if _LSP_IMPORT_ATTEMPTS < 20:
            _LSP_IMPORT_ATTEMPTS += 1
            sublime.set_timeout(_try_register_lsp, 500)
        return

    class KovyLspPlugin(LspPlugin):

        @classmethod
        def on_pre_start_async(cls, context):
            python = _python_path()
            server = _server_path()
            if not python:
                raise PluginStartError(
                    "Kovy: Python 3 was not found. Set \"kovy_python\" in "
                    "Packages/Kovy/Kovy.sublime-settings."
                )
            if not os.path.isfile(server):
                raise PluginStartError(
                    "Kovy: kovy_lsp.py was not found at %s. Set "
                    "\"kovy_lsp_server\" in Packages/Kovy/Kovy.sublime-settings."
                    % server
                )
            context.variables["kovy_python"] = python
            context.variables["kovy_server"] = server
            compiler = _compiler_path()
            if compiler:
                context.configuration.initialization_options.set("kovyPath", compiler)

        def _store_all(self):
            session = self.weaksession()
            if session is None:
                return
            for session_view in list(session.session_views_async()):
                view = session_view.view
                if _is_kovy(view):
                    _store_diagnostics(view, session_view.session_buffer)

        def on_initialized_async(self):
            sublime.set_timeout(self._store_all, 100)

        def on_selection_modified_async(self, session_view):
            view = session_view.view
            if _is_kovy(view):
                _store_diagnostics(view, session_view.session_buffer)

        def on_text_changed_async(self, session_buffer):
            for session_view in list(session_buffer.session_views):
                view = session_view.view
                if _is_kovy(view):
                    _store_diagnostics(view, session_buffer)

        def on_server_notification_async(self, notification):
            if notification.get("method") != "textDocument/publishDiagnostics":
                return
            # LSP handles the notification after this hook; wait for the
            # diagnostics list to be updated before refreshing the panels.
            sublime.set_timeout(self._store_all, 120)

    KovyLspPlugin.register()
    _LSP_PLUGIN_CLASS = KovyLspPlugin


class KovyEventListener(sublime_plugin.EventListener):

    def on_activated_async(self, view):
        if _is_kovy(view):
            sublime.set_timeout(lambda: _update_panel_for_view(view), 0)

    def on_selection_modified_async(self, view):
        if _is_kovy(view) and view.id() in _DIAGNOSTICS:
            sublime.set_timeout(lambda: _update_panel_for_view(view), 0)

    def on_close(self, view):
        _DIAGNOSTICS.pop(view.id(), None)


def plugin_loaded():
    _try_register_lsp()


def plugin_unloaded():
    global _LSP_PLUGIN_CLASS
    if _LSP_PLUGIN_CLASS is not None:
        try:
            _LSP_PLUGIN_CLASS.unregister()
        except Exception:
            pass
        _LSP_PLUGIN_CLASS = None
    _DIAGNOSTICS.clear()