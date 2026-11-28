#!/usr/bin/env python3
"""Minimal Kovy language server.

The server implements the LSP transport and document lifecycle.  Diagnostics
come from the compiler's stable JSON report:

    kovy check --json - --name <document path>

Only diagnostics are implemented for now.  Hover, completion, and
go-to-definition can be added later without changing the transport layer.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import traceback
from urllib.parse import unquote, urlparse


VERSION = "0.1.0"
SERVER_NAME = "kovy-lsp"

DEFAULT_SETTINGS = {
    "kovyPath": "",
    "noNimgen": False,
    "locale": "",
    "localePath": "",
    "extraArgs": [],
    "debounceMs": 300,
    "timeoutMs": 20000,
    "checkOnOpen": True,
    "checkOnChange": True,
    "checkOnSave": True,
}

_WRITE_LOCK = threading.Lock()
_LOG_ENABLED = os.environ.get("KOVY_LSP_LOG", "") not in ("", "0", "false", "no")


def log(message):
    if _LOG_ENABLED:
        sys.stderr.write("[kovy-lsp] %s\n" % message)
        sys.stderr.flush()


class ProtocolError(Exception):
    pass


def read_message(stream):
    """Read one Content-Length framed JSON-RPC message, or None on EOF."""
    headers = {}
    while True:
        line = stream.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        try:
            text = line.decode("ascii").strip()
        except UnicodeDecodeError as error:
            raise ProtocolError("non-ASCII header: %s" % error)
        if not text:
            break
        key, separator, value = text.partition(":")
        if not separator:
            raise ProtocolError("malformed header: %r" % text)
        headers[key.strip().lower()] = value.strip()

    if "content-length" not in headers:
        raise ProtocolError("missing Content-Length header")
    try:
        length = int(headers["content-length"])
    except ValueError:
        raise ProtocolError("invalid Content-Length: %r" % headers["content-length"])
    if length < 0:
        raise ProtocolError("negative Content-Length")

    chunks = []
    remaining = length
    while remaining > 0:
        chunk = stream.read(remaining)
        if not chunk:
            raise ProtocolError("truncated message body")
        chunks.append(chunk)
        remaining -= len(chunk)

    body = b"".join(chunks)
    try:
        message = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ProtocolError("invalid JSON body: %s" % error)
    if not isinstance(message, dict):
        raise ProtocolError("message is not a JSON object")
    return message


def write_message(payload):
    data = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    header = ("Content-Length: %d\r\n\r\n" % len(data)).encode("ascii")
    with _WRITE_LOCK:
        sys.stdout.buffer.write(header)
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()


def uri_to_path(uri):
    if not uri or not isinstance(uri, str):
        return None
    parsed = urlparse(uri)
    if parsed.scheme != "file":
        return None
    path = unquote(parsed.path)
    if parsed.netloc and parsed.netloc not in ("", "localhost"):
        path = "//" + parsed.netloc + path
    if os.name == "nt" and re.match(r"^/[A-Za-z]:", path):
        path = path[1:]
    return os.path.normpath(path)


def _utf16_length(text):
    return len(text.encode("utf-16-le")) // 2


def _line_texts(text):
    return text.splitlines()


def _byte_offset_to_utf16(line_text, byte_offset):
    raw = line_text.encode("utf-8")
    byte_offset = max(0, min(int(byte_offset), len(raw)))
    prefix = raw[:byte_offset].decode("utf-8", "replace")
    return _utf16_length(prefix)


def _diagnostic_range(diagnostic, text):
    lines = _line_texts(text)
    try:
        line_index = max(0, int(diagnostic.get("line", 1)) - 1)
        column = max(1, int(diagnostic.get("column", 1)))
        length = max(0, int(diagnostic.get("length", 0) or 0))
    except (TypeError, ValueError):
        line_index, column, length = 0, 1, 0

    if not lines:
        lines = [""]
    line_index = min(line_index, len(lines) - 1)
    line_text = lines[line_index]
    raw = line_text.encode("utf-8")
    start_byte = min(column - 1, len(raw))
    end_byte = min(start_byte + length, len(raw))
    start_character = _byte_offset_to_utf16(line_text, start_byte)
    end_character = _byte_offset_to_utf16(line_text, end_byte)
    if end_character < start_character:
        end_character = start_character
    return {
        "start": {"line": line_index, "character": start_character},
        "end": {"line": line_index, "character": end_character},
    }


def _severity(value):
    return {
        "error": 1,
        "warning": 2,
        "information": 3,
        "info": 3,
        "hint": 4,
    }.get(str(value or "").lower(), 1)


def _report_int(diagnostic, key, default):
    try:
        return int(diagnostic.get(key, default))
    except (TypeError, ValueError):
        return default


def _to_lsp_diagnostic(diagnostic, text):
    if not isinstance(diagnostic, dict):
        raise ValueError("diagnostic is not an object")

    # The LSP message is what hover popups and the status bar display, so it
    # includes the optional addinfo.  The original message and addinfo are
    # also kept separately in `data` for clients that render their own panel.
    message_text = str(diagnostic.get("message") or "")
    addinfo = str(diagnostic.get("addinfo") or "").strip()
    message = message_text
    if addinfo:
        message = message + "\n\n" + addinfo

    result = {
        "range": _diagnostic_range(diagnostic, text),
        "severity": _severity(diagnostic.get("severity")),
        "source": "kovy",
        "message": message,
    }
    kind = diagnostic.get("kind")
    if kind:
        result["code"] = str(kind)
    result["data"] = {
        "kind": kind,
        "phase": diagnostic.get("phase"),
        "severity": diagnostic.get("severity"),
        "message": message_text,
        "addinfo": addinfo,
        "line": _report_int(diagnostic, "line", 0),
        "column": _report_int(diagnostic, "column", 0),
        "length": _report_int(diagnostic, "length", 0),
        "sourceLine": diagnostic.get("sourceLine"),
    }
    return result


def _position_to_offset(text, position):
    try:
        line_index = max(0, int(position.get("line", 0)))
        character = max(0, int(position.get("character", 0)))
    except (TypeError, ValueError):
        return 0

    lines = text.splitlines(keepends=True)
    if line_index >= len(lines):
        return len(text)
    offset = sum(len(line) for line in lines[:line_index])
    line = lines[line_index]
    units = 0
    index = 0
    for char in line:
        if char in "\r\n":
            break
        next_units = units + _utf16_length(char)
        if next_units > character:
            break
        units = next_units
        index += len(char)
    return offset + index


def _apply_content_changes(text, changes):
    for change in changes or []:
        if not isinstance(change, dict):
            continue
        replacement = change.get("text")
        if not isinstance(replacement, str):
            continue
        if "range" in change:
            range_ = change["range"] or {}
            start = _position_to_offset(text, range_.get("start") or {})
            end = _position_to_offset(text, range_.get("end") or {})
            if end < start:
                start, end = end, start
            text = text[:start] + replacement + text[end:]
        else:
            text = replacement
    return text


def _windows_startupinfo():
    if os.name != "nt":
        return {}
    info = subprocess.STARTUPINFO()
    info.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    return {"startupinfo": info, "creationflags": subprocess.CREATE_NO_WINDOW}


class Document:
    __slots__ = (
        "uri",
        "text",
        "version",
        "language_id",
        "path",
        "revision",
        "timer",
        "diagnostics",
        "last_error",
    )

    def __init__(self, uri, text, version, language_id):
        self.uri = uri
        self.text = text
        self.version = version
        self.language_id = language_id
        self.path = uri_to_path(uri)
        self.revision = 0
        self.timer = None
        self.diagnostics = []
        self.last_error = ""


class Server:
    def __init__(self):
        self.config = dict(DEFAULT_SETTINGS)
        self.docs = {}
        self.lock = threading.RLock()
        self.roots = []
        self.shutdown_requested = False
        self.exit_requested = False
        self.last_reported_error = ""

    # -- transport -------------------------------------------------------

    def send(self, payload):
        write_message(payload)

    def respond(self, request_id, result):
        self.send({"jsonrpc": "2.0", "id": request_id, "result": result})

    def respond_error(self, request_id, code, message):
        self.send(
            {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": code, "message": message},
            }
        )

    def publish(self, uri, version, diagnostics):
        params = {"uri": uri, "diagnostics": diagnostics}
        if version is not None:
            params["version"] = version
        self.send(
            {
                "jsonrpc": "2.0",
                "method": "textDocument/publishDiagnostics",
                "params": params,
            }
        )

    def report_error(self, message):
        if not message or message == self.last_reported_error:
            return
        self.last_reported_error = message
        self.send(
            {
                "jsonrpc": "2.0",
                "method": "window/showMessage",
                "params": {"type": 1, "message": "Kovy: " + message},
            }
        )

    # -- lifecycle -------------------------------------------------------

    def run(self):
        while not self.exit_requested:
            try:
                message = read_message(sys.stdin.buffer)
            except ProtocolError as error:
                log("protocol error: %s" % error)
                break
            if message is None:
                break
            try:
                self.handle(message)
            except Exception:
                log("unhandled error:\n" + traceback.format_exc())
        self.cleanup()
        return 0 if self.shutdown_requested else 1

    def cleanup(self):
        with self.lock:
            documents = list(self.docs.values())
            self.docs.clear()
        for document in documents:
            if document.timer is not None:
                document.timer.cancel()

    def handle(self, message):
        method = message.get("method")
        if not isinstance(method, str):
            return
        params = message.get("params") or {}
        if "id" in message:
            self.handle_request(message["id"], method, params)
        else:
            self.handle_notification(method, params)

    def handle_request(self, request_id, method, params):
        if method == "initialize":
            self.respond(request_id, self.initialize(params))
        elif method == "shutdown":
            self.shutdown()
            self.respond(request_id, None)
        else:
            self.respond_error(request_id, -32601, "Method not found: %s" % method)

    def handle_notification(self, method, params):
        if method == "initialized":
            return
        if method == "exit":
            self.exit_requested = True
            return
        if method == "textDocument/didOpen":
            self.did_open(params)
        elif method == "textDocument/didChange":
            self.did_change(params)
        elif method == "textDocument/didSave":
            self.did_save(params)
        elif method == "textDocument/didClose":
            self.did_close(params)
        elif method == "workspace/didChangeConfiguration":
            self.did_change_configuration(params)
        elif method == "workspace/didChangeWorkspaceFolders":
            self.did_change_workspace_folders(params)
        elif method in ("$/cancelRequest", "$/setTrace", "window/workDoneProgress/cancel"):
            return
        else:
            log("ignoring notification: %s" % method)

    def shutdown(self):
        with self.lock:
            self.shutdown_requested = True
            documents = list(self.docs.values())
        for document in documents:
            if document.timer is not None:
                document.timer.cancel()
                document.timer = None

    def initialize(self, params):
        self.roots = []
        for folder in params.get("workspaceFolders") or []:
            if isinstance(folder, dict):
                path = uri_to_path(folder.get("uri"))
                if path:
                    self.roots.append(path)
        if not self.roots:
            path = uri_to_path(params.get("rootUri"))
            if path:
                self.roots.append(path)
        root_path = params.get("rootPath")
        if isinstance(root_path, str) and root_path:
            self.roots.append(os.path.normpath(root_path))

        options = params.get("initializationOptions") or {}
        self.update_config(options)

        log(
            "initialize: roots=%r kovyPath=%r noNimgen=%r"
            % (self.roots, self.config["kovyPath"], self.config["noNimgen"])
        )
        return {
            "capabilities": {
                "positionEncoding": "utf-16",
                "textDocumentSync": {
                    "openClose": True,
                    "change": 1,
                    "save": {"includeText": True},
                },
                "workspace": {
                    "workspaceFolders": {
                        "supported": True,
                        "changeNotifications": True,
                    }
                },
            },
            "serverInfo": {"name": SERVER_NAME, "version": VERSION},
        }

    # -- configuration ---------------------------------------------------

    def update_config(self, options):
        if not isinstance(options, dict):
            return
        nested = options.get("kovy")
        if isinstance(nested, dict):
            options = nested

        for key in DEFAULT_SETTINGS:
            if key not in options:
                continue
            value = options[key]
            if key == "extraArgs":
                if isinstance(value, list):
                    self.config[key] = [str(item) for item in value]
                elif value is None:
                    self.config[key] = []
            elif key in ("noNimgen", "checkOnOpen", "checkOnChange", "checkOnSave"):
                if isinstance(value, str):
                    self.config[key] = value.strip().lower() not in (
                        "",
                        "0",
                        "false",
                        "no",
                        "off",
                    )
                else:
                    self.config[key] = bool(value)
            elif key in ("debounceMs", "timeoutMs"):
                try:
                    number = int(value)
                except (TypeError, ValueError):
                    continue
                if key == "debounceMs":
                    self.config[key] = max(0, min(number, 5000))
                else:
                    self.config[key] = max(1000, min(number, 120000))
            elif isinstance(value, str):
                self.config[key] = value
            elif value is None:
                self.config[key] = ""

    def did_change_configuration(self, params):
        settings = params.get("settings") or {}
        self.update_config(settings)
        with self.lock:
            uris = list(self.docs.keys())
        for uri in uris:
            self.schedule(uri, immediate=True)

    def did_change_workspace_folders(self, params):
        event = params.get("event") or {}
        removed = set()
        for folder in event.get("removed") or []:
            if isinstance(folder, dict):
                path = uri_to_path(folder.get("uri"))
                if path:
                    removed.add(path)
        if removed:
            self.roots = [root for root in self.roots if root not in removed]
        for folder in event.get("added") or []:
            if isinstance(folder, dict):
                path = uri_to_path(folder.get("uri"))
                if path and path not in self.roots:
                    self.roots.append(path)
        with self.lock:
            uris = list(self.docs.keys())
        for uri in uris:
            self.schedule(uri, immediate=True)

    # -- document lifecycle ---------------------------------------------

    def did_open(self, params):
        item = params.get("textDocument") or {}
        uri = item.get("uri")
        if not isinstance(uri, str):
            return
        document = Document(
            uri,
            str(item.get("text") or ""),
            item.get("version"),
            item.get("languageId"),
        )
        with self.lock:
            self.docs[uri] = document
        if self.config["checkOnOpen"]:
            self.schedule(uri, immediate=True)

    def did_change(self, params):
        item = params.get("textDocument") or {}
        uri = item.get("uri")
        if not isinstance(uri, str):
            return
        with self.lock:
            document = self.docs.get(uri)
            if document is None:
                return
            document.text = _apply_content_changes(
                document.text, params.get("contentChanges") or []
            )
            document.version = item.get("version")
        if self.config["checkOnChange"]:
            self.schedule(uri)

    def did_save(self, params):
        item = params.get("textDocument") or {}
        uri = item.get("uri")
        if not isinstance(uri, str):
            return
        text = params.get("text")
        with self.lock:
            document = self.docs.get(uri)
            if document is None:
                return
            if isinstance(text, str):
                document.text = text
            document.version = item.get("version", document.version)
        if self.config["checkOnSave"]:
            self.schedule(uri, immediate=True)

    def did_close(self, params):
        item = params.get("textDocument") or {}
        uri = item.get("uri")
        if not isinstance(uri, str):
            return
        with self.lock:
            document = self.docs.pop(uri, None)
        if document is not None and document.timer is not None:
            document.timer.cancel()
        self.publish(uri, None, [])

    # -- checking --------------------------------------------------------

    def schedule(self, uri, immediate=False):
        if self.shutdown_requested:
            return
        with self.lock:
            document = self.docs.get(uri)
            if document is None:
                return
            document.revision += 1
            revision = document.revision
            timer = document.timer
            if timer is not None:
                timer.cancel()
            delay = 0.0 if immediate else self.config["debounceMs"] / 1000.0
            timer = threading.Timer(delay, self._check, args=(uri, revision))
            timer.daemon = True
            document.timer = timer
            timer.start()

    def _check(self, uri, revision):
        with self.lock:
            document = self.docs.get(uri)
            if document is None or document.revision != revision:
                return
            text = document.text
            path = document.path
            document.timer = None

        diagnostics, error = self._run_check(text, path)

        with self.lock:
            document = self.docs.get(uri)
            if document is None or document.revision != revision:
                return
            document.diagnostics = diagnostics
            document.last_error = error
            version = document.version

        if self.shutdown_requested:
            return
        if error:
            self.report_error(error)
        else:
            self.last_reported_error = ""
        self.publish(uri, version, diagnostics)

    def _search_roots(self, path):
        roots = []
        if path:
            roots.append(os.path.dirname(path))
        roots.extend(self.roots)
        roots.append(os.getcwd())

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

    def _resolve_kovy(self, path):
        candidates = []
        if self.config["kovyPath"]:
            candidates.append(self.config["kovyPath"])
        environment = os.environ.get("KOVY_BIN")
        if environment:
            candidates.append(environment)
        candidates.append("kovy")

        for candidate in candidates:
            expanded = os.path.expanduser(os.path.expandvars(str(candidate)))
            if not expanded:
                continue
            has_separator = os.sep in expanded or (
                os.altsep and os.altsep in expanded
            )
            if os.path.isabs(expanded) or has_separator:
                if not os.path.isabs(expanded):
                    roots = self._search_roots(path)
                    if not roots:
                        continue
                    expanded = os.path.join(roots[0], expanded)
                expanded = os.path.abspath(expanded)
                if self._is_executable(expanded):
                    return expanded
            else:
                found = shutil.which(expanded)
                if found:
                    return found

        names = ["kovy.exe", "kovy"] if os.name == "nt" else ["kovy", "kovy.exe"]
        for root in self._search_roots(path):
            current = root
            for _ in range(6):
                for name in names:
                    candidate = os.path.join(current, "bin", name)
                    if self._is_executable(candidate):
                        return candidate
                parent = os.path.dirname(current)
                if parent == current:
                    break
                current = parent
        return None

    @staticmethod
    def _is_executable(path):
        if not os.path.isfile(path):
            return False
        if os.name == "nt":
            return True
        return os.access(path, os.X_OK)

    def _command(self, executable, path):
        name = path or "buffer.kovy"
        args = [executable, "check", "--json"]

        locale_path = os.path.expanduser(
            os.path.expandvars(self.config["localePath"])
        )
        if locale_path:
            args.extend(["--locale-path", locale_path])
        elif self.config["locale"]:
            args.extend(["--locale", self.config["locale"]])

        if self.config["noNimgen"]:
            args.append("--no-nimgen")

        args.extend(self.config["extraArgs"])
        args.extend(["--name", name, "-"])
        return args

    def _run_check(self, text, path):
        executable = self._resolve_kovy(path)
        if not executable:
            return [], (
                "Kovy executable was not found. Set initializationOptions.kovyPath "
                "or the KOVY_BIN environment variable."
            )

        args = self._command(executable, path)
        roots = self._search_roots(path)
        cwd = None
        if path and os.path.isdir(os.path.dirname(path)):
            cwd = os.path.dirname(path)
        elif roots and os.path.isdir(roots[0]):
            cwd = roots[0]

        try:
            completed = subprocess.run(
                args,
                input=text.encode("utf-8"),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=cwd,
                timeout=max(1.0, self.config["timeoutMs"] / 1000.0),
                **_windows_startupinfo()
            )
        except FileNotFoundError:
            return [], "Could not start kovy: %s" % executable
        except subprocess.TimeoutExpired:
            return [], "kovy check timed out after %d ms" % self.config["timeoutMs"]
        except OSError as error:
            return [], "Could not run kovy: %s" % error

        stdout = completed.stdout.decode("utf-8", "replace")
        stderr = completed.stderr.decode("utf-8", "replace")

        if completed.returncode not in (0, 1):
            return [], stderr.strip() or (
                "kovy check exited with status %d" % completed.returncode
            )

        try:
            report = json.loads(stdout)
        except json.JSONDecodeError as error:
            return [], "Invalid JSON from kovy: %s\n%s" % (
                error,
                stderr.strip()[:4000],
            )
        if not isinstance(report, dict):
            return [], "Invalid kovy report: expected a JSON object"
        if report.get("schemaVersion") != 1:
            return [], "Unsupported kovy report schemaVersion: %r" % (
                report.get("schemaVersion"),
            )
        raw_diagnostics = report.get("diagnostics")
        if not isinstance(raw_diagnostics, list):
            return [], "Invalid kovy report: diagnostics is not an array"

        diagnostics = []
        for raw in raw_diagnostics:
            try:
                diagnostics.append(_to_lsp_diagnostic(raw, text))
            except Exception as error:
                log("skipping malformed diagnostic %r: %s" % (raw, error))
        return diagnostics, ""


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Kovy language server (diagnostics via kovy check --json)"
    )
    parser.add_argument("--version", action="version", version=SERVER_NAME + " " + VERSION)
    parser.add_argument(
        "--stdio",
        action="store_true",
        help="use stdio transport (the default and only transport)",
    )
    parser.parse_args(argv)

    server = Server()
    try:
        return server.run()
    except KeyboardInterrupt:
        return 1
    except Exception:
        sys.stderr.write(traceback.format_exc())
        sys.stderr.flush()
        return 1


if __name__ == "__main__":
    sys.exit(main())