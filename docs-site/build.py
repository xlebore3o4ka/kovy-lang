#!/usr/bin/env python3
"""Build a static documentation site for the Kovy language docs.

The source of truth is the Markdown tree in the repository (`docs/`).
This script renders every page, fixes cross-document links, creates a
client-side search index, and writes a self-contained static site to `site/`.

Usage:
    python3 build.py [--docs /path/to/kovy-lang/docs] [--out site]
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import html
import json
import os
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path

import markdown
from markdown.extensions import Extension
from markdown.preprocessors import Preprocessor
from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexer import RegexLexer
from pygments.lexers import get_lexer_by_name
from pygments.lexers.special import TextLexer
from pygments.token import (
    Keyword,
    Name,
    Number,
    Operator,
    Punctuation,
    String,
    Text,
    Whitespace,
)
from pygments.util import ClassNotFound

PROJECT_DIR = Path(__file__).resolve().parent
DEFAULT_DOCS = Path(os.environ.get("KOVY_DOCS", PROJECT_DIR.parent / "docs"))
REPO_URL = "https://github.com/xlebore3o4ka/kovy-lang"
BRANCH = "master"
DEFAULT_SITE_URL = "https://xlebore3o4ka.github.io/kovy-lang"
SITE_URL = os.environ.get("KOVY_SITE_URL", DEFAULT_SITE_URL).rstrip("/")
DOCS_VERSION = os.environ.get("KOVY_DOCS_VERSION", "0.1")
BUILD_DATE = os.environ.get("KOVY_BUILD_DATE") or datetime.date.today().isoformat()
ASSET_VERSION = (
    os.environ.get("KOVY_ASSET_VERSION")
    or os.environ.get("GITHUB_SHA")
    or BUILD_DATE
)[:12]


def compute_asset_version(docs: Path) -> str:
    """Short content hash so a rebuild always busts CSS/JS/search caches."""
    digest = hashlib.sha1()
    for name in ("style.css", "app.js"):
        digest.update((PROJECT_DIR / "assets" / name).read_bytes())
    for source in sorted(docs.rglob("*.md")):
        digest.update(source.read_bytes())
    return digest.hexdigest()[:12]


# ---------------------------------------------------------------------------
# Syntax highlighting
# ---------------------------------------------------------------------------


class KovyLexer(RegexLexer):
    """A deliberately small lexer for the language shown in the docs."""

    name = "Kovy"
    aliases = ["kovy"]
    filenames = ["*.kovy"]

    tokens = {
        "root": [
            (r"[ \t]+", Whitespace),
            (r"\n", Whitespace),
            (r"\b(int|bool|void)\b", Keyword.Type),
            (r"\b(true|false)\b", Keyword.Constant),
            (r"\b(alloc|addr|mut|of)\b", Keyword.Declaration),
            (r"\b(if|elif|else|while|break|continue|return|not|and|or)\b", Keyword),
            (r"\b[A-Za-z_]\w*(?=\s*\()", Name.Function),
            (r"\b[A-Za-z_]\w*\b", Name),
            (r"\b\d+\b", Number.Integer),
            (r">=|<=|==|!=|[+\-*/=<>#:;,()\[\]]", Operator),
            (r".", Text),
        ]
    }


KOVY_LEXER = KovyLexer(stripnl=False, ensurenl=False)
FORMATTER = HtmlFormatter(nowrap=True)


def code_lexer(lang: str):
    if lang == "kovy":
        return KOVY_LEXER
    try:
        return get_lexer_by_name(lang, stripnl=False, ensurenl=False)
    except ClassNotFound:
        return TextLexer(stripnl=False, ensurenl=False)


# ---------------------------------------------------------------------------
# Markdown fenced code
# ---------------------------------------------------------------------------

FENCE_OPEN_RE = re.compile(r"^(?P<indent>[ \t]*)(?P<marker>`{3,}|~{3,})(?P<info>[^\n]*)$")
EXPECT_RE = re.compile(r"^\s*<!--\s*expect-errors:\s*(.+?)\s*-->\s*$", re.I)


def fence_close_re(char: str, size: int) -> re.Pattern[str]:
    return re.compile(rf"^[ \t]*{re.escape(char)}{{{size},}}[ \t]*$")


def find_fence_end(lines: list[str], start: int, char: str, size: int, lang: str) -> int:
    close_re = fence_close_re(char, size)
    candidates = []
    for i in range(start + 1, len(lines)):
        if close_re.match(lines[i]):
            candidates.append(i)
    if not candidates:
        return len(lines)

    # The source docs contain a few Markdown examples that themselves contain
    # fenced code. CommonMark would close those early, so for `markdown` fences
    # prefer the last fence followed by a real top-level heading or EOF.
    if lang == "markdown" and len(candidates) > 1:
        for i in candidates:
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j >= len(lines) or re.match(r"^#{1,6}\s+", lines[j]):
                return i
    return candidates[0]


def render_code_block(code: str, lang: str, expect: str | None) -> str:
    lang = (lang or "text").strip().split()[0].lower()
    code = code.strip("\n")
    lexer = code_lexer(lang)
    highlighted = highlight(code, lexer, FORMATTER).rstrip("\n")
    label = html.escape(lang)

    note = ""
    if expect:
        value = expect.strip()
        if value.upper() == "OK":
            note = '<span class="code-note code-note-pass" title="Checked by the documentation test suite">pass</span>'
        else:
            kinds = [part.strip() for part in value.split(",") if part.strip()]
            shown = ", ".join(kinds[:2])
            if len(kinds) > 2:
                shown += f" +{len(kinds) - 2}"
            note = (
                f'<span class="code-note code-note-error" title="{html.escape(value)}">'
                f"<code>{html.escape(shown)}</code></span>"
            )

    return (
        '<div class="codeblock">'
        '<div class="codeblock-bar">'
        f'<span class="code-lang">{label}</span>'
        f"{note}"
        '<button class="code-copy" type="button" aria-label="Copy code">Copy</button>'
        "</div>"
        f'<pre class="code-pre"><code class="language-{label}">{highlighted}</code></pre>'
        "</div>"
    )


class FencePreprocessor(Preprocessor):
    def run(self, lines: list[str]) -> list[str]:
        output: list[str] = []
        i = 0
        pending_expect: str | None = None

        while i < len(lines):
            line = lines[i]
            expect_match = EXPECT_RE.match(line)
            if expect_match:
                pending_expect = expect_match.group(1)
                i += 1
                continue

            open_match = FENCE_OPEN_RE.match(line)
            if not open_match:
                output.append(line)
                i += 1
                continue

            marker = open_match.group("marker")
            char, size = marker[0], len(marker)
            info = open_match.group("info").strip()
            lang = info.split()[0] if info else "text"
            end = find_fence_end(lines, i, char, size, lang)
            code_lines = lines[i + 1 : end]

            # Remove the indentation of the opening fence from the body.
            indent = open_match.group("indent")
            if indent:
                code_lines = [
                    ln[len(indent) :] if ln.startswith(indent) else ln for ln in code_lines
                ]

            html_block = render_code_block("\n".join(code_lines), lang, pending_expect)
            output.append(self.md.htmlStash.store(html_block))
            pending_expect = None
            i = end + 1

        return output


class KovyDocsExtension(Extension):
    def extendMarkdown(self, md: markdown.Markdown) -> None:
        md.preprocessors.register(FencePreprocessor(md), "kovy_fences", 25)


# ---------------------------------------------------------------------------
# Pages
# ---------------------------------------------------------------------------


@dataclass
class Page:
    rel: str
    src: Path
    out: str
    title: str
    description: str
    meta: dict[str, str]
    body: str
    toc_tokens: list[dict]
    group: str
    entries: list[dict] = field(default_factory=list)

    @property
    def url(self) -> str:
        return self.out

    @property
    def root(self) -> str:
        depth = len(Path(self.out).parent.parts)
        return "../" * depth


GROUP_INFO = {
    "guides": {"label": "Guides", "blurb": "Short, complete programs"},
    "language": {"label": "Language", "blurb": "Syntax and semantics"},
    "reference": {"label": "Reference", "blurb": "Tables and indexes"},
    "errors": {"label": "Errors", "blurb": "Every diagnostic"},
    "internals": {"label": "Internals", "blurb": "Compiler implementation"},
    "meta": {"label": "Meta", "blurb": "Documentation maintenance"},
}

NAV_GROUPS = [
    (
        "guides",
        [
            "guides/hello-world.md",
            "guides/rpn.md",
            "guides/arrays.md",
            "guides/pointers-alloc.md",
            "guides/functions-overloads.md",
        ],
    ),
    (
        "language",
        [
            "language/overview.md",
            "language/lexical.md",
            "language/grammar.md",
            "language/indentation.md",
            "language/types.md",
            "language/declarations.md",
            "language/expressions.md",
            "language/statements.md",
            "language/control-flow.md",
            "language/functions.md",
            "language/overloads.md",
            "language/scopes.md",
            "language/mutability.md",
            "language/pointers.md",
            "language/arrays.md",
            "language/pipeline.md",
        ],
    ),
    (
        "reference",
        [
            "reference/keywords.md",
            "reference/cli.md",
            "reference/tokens.md",
            "reference/operators.md",
            "reference/precedence.md",
            "reference/syntax-index.md",
            "reference/semantics-index.md",
            "reference/type-compatibility.md",
            "reference/error-index.md",
            "reference/test-map.md",
        ],
    ),
    ("errors", []),  # filled dynamically: index first, then alphabetical
    (
        "internals",
        [
            "internals/ast.md",
            "internals/sema.md",
            "internals/types.md",
            "internals/nimgen.md",
            "internals/runtime.md",
            "internals/error-system.md",
        ],
    ),
    (
        "meta",
        [
            "_meta/id-scheme.md",
            "_meta/page-templates.md",
            "_meta/coverage.md",
            "_meta/verification.md",
            "README.md",
            "TODO.md",
        ],
    ),
]

LABEL_OVERRIDES = {
    "errors/index.md": "All errors",
    "language/overview.md": "Overview",
    "TODO.md": "Documentation plan",
    "README.md": "About the docs",
}


def strip_inline(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"!\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
    text = text.replace("`", "")
    text = re.sub(r"[*_]{1,3}([^*_]+)[*_]{1,3}", r"\1", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def html_to_text(value: str) -> str:
    value = re.sub(r"<br\s*/?>", "\n", value, flags=re.I)
    value = re.sub(r"</(p|div|pre|li|tr|h[1-6])>", "\n", value, flags=re.I)
    value = re.sub(r"<[^>]+>", " ", value)
    value = html.unescape(value)
    value = re.sub(r"[ \t\r\f\v]+", " ", value)
    value = re.sub(r" *\n *", "\n", value)
    value = re.sub(r"\n{2,}", "\n", value)
    return value.strip()


ANCHOR_LINE_RE = re.compile(r'^\s*<a id="[^"]+"></a>\s*$')


def normalize_anchor_blocks(source: str) -> str:
    """Give stable anchors their own block so they do not interrupt lists."""
    lines = source.split("\n")
    output: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        open_match = FENCE_OPEN_RE.match(line)
        if open_match:
            marker = open_match.group("marker")
            char, size = marker[0], len(marker)
            info = open_match.group("info").strip()
            lang = info.split()[0] if info else "text"
            end = find_fence_end(lines, i, char, size, lang)
            output.extend(lines[i : end + 1])
            i = end + 1
            continue

        if ANCHOR_LINE_RE.match(line):
            if output and output[-1].strip():
                output.append("")
            output.append(line)
            output.append("")
        else:
            output.append(line)
        i += 1
    return "\n".join(output)


def extract_description(source: str) -> str:
    blocks = re.split(r"\n\s*\n", source)
    for block in blocks:
        value = block.strip()
        if not value:
            continue
        if value.startswith(("#", "<!--", "<a ", "|", "```", "- ", "* ", "1.", ">", "    ")):
            continue
        text = strip_inline(value)
        if len(text) < 16:
            continue
        text = re.sub(r"\s+", " ", text)
        return text[:180].rstrip() + ("…" if len(text) > 180 else "")
    return ""


def load_page(src: Path, docs: Path) -> Page:
    rel = src.relative_to(docs).as_posix()
    out = rel[:-3] + ".html" if rel.endswith(".md") else rel + ".html"
    source = src.read_text(encoding="utf-8")

    meta: dict[str, str] = {}
    for key in ("doc-id", "kind", "status", "phase"):
        match = re.search(rf"<!--\s*{re.escape(key)}:\s*(.+?)\s*-->", source)
        if match:
            meta[key] = match.group(1)

    title_match = re.search(r"^#\s+(.+?)\s*$", source, re.M)
    title = strip_inline(title_match.group(1)) if title_match else src.stem
    if title_match:
        source = source[: title_match.start()] + source[title_match.end() :]

    source = re.sub(
        r"^<!--\s*(doc-id|kind|status|phase):.*?-->\s*$", "", source, flags=re.M
    )

    source = normalize_anchor_blocks(source)
    description = extract_description(source)
    md = markdown.Markdown(
        extensions=["tables", "toc", "sane_lists", KovyDocsExtension()],
        extension_configs={"toc": {"toc_depth": "2-3", "permalink": False}},
        output_format="html5",
    )
    body = md.convert(source)
    toc_tokens = list(getattr(md, "toc_tokens", []))

    # Move standalone stable anchors out of paragraphs so they stay invisible.
    body = re.sub(r"<p>\s*(<a id=\"[^\"]+\"></a>)\s*</p>", r"\1", body)
    body = re.sub(r"<p>\s*(<a id=\"[^\"]+\"></a>)(?!\s*</p>)", r"\1<p>", body)
    body = re.sub(r"(<table>.*?</table>)", r'<div class="table-wrap">\1</div>', body, flags=re.S)

    if not description:
        description_source = html_to_text(body)
        description = re.sub(r"\s+", " ", description_source)[:180].strip()
        if len(description_source) > 180:
            description = description.rstrip() + "…"

    group = rel.split("/", 1)[0] if "/" in rel else "meta"

    page = Page(
        rel=rel,
        src=src,
        out=out,
        title=title,
        description=description,
        meta=meta,
        body=body,
        toc_tokens=toc_tokens,
        group=group,
    )
    page.entries = build_search_entries(page)
    return page


def rewrite_links(page: Page, pages: dict[str, Page]) -> str:
    href_re = re.compile(r'(<a\b[^>]*\bhref=")([^"]+)(")', re.I)

    def repl(match: re.Match[str]) -> str:
        before, href, after = match.group(1), match.group(2), match.group(3)
        if not href or href.startswith(("http://", "https://", "mailto:", "tel:", "/")):
            return match.group(0)

        path, has_hash, fragment = href.partition("#")
        if not path:
            return match.group(0)
        if not path.endswith(".md"):
            return match.group(0)

        target_src = os.path.normpath(
            (Path(page.rel).parent / path).as_posix()
        ).lstrip("./")
        target = pages.get(target_src)
        if target is None:
            return match.group(0)

        relative = os.path.relpath(target.out, start=str(Path(page.out).parent))
        relative = Path(relative).as_posix()
        if relative == ".":
            relative = Path(target.out).name
        if has_hash:
            relative += "#" + fragment
        return f"{before}{relative}{after}"

    return href_re.sub(repl, page.body)


def search_text(value: str) -> str:
    value = re.sub(r'<div class="codeblock-bar">.*?</div>', "", value, flags=re.S)
    return html_to_text(value)


def build_search_entries(page: Page) -> list[dict]:
    heading_re = re.compile(
        r'<h([23])\b[^>]*\bid="([^"]+)"[^>]*>(.*?)</h\1>', re.S | re.I
    )
    matches = list(heading_re.finditer(page.body))
    entries: list[dict] = []
    group_label = GROUP_INFO.get(page.group, {}).get("label", "Docs")

    def add(section: str, text: str, url: str) -> None:
        text = re.sub(r"\s+", " ", text).strip()
        if not text:
            return
        entries.append(
            {
                "t": page.title,
                "s": section,
                "u": url,
                "g": group_label,
                "x": text[:2800],
            }
        )

    if matches:
        intro = search_text(page.body[: matches[0].start()])
        add("", intro, page.out)
        parent_h2 = ""
        for index, match in enumerate(matches):
            level, anchor, heading_html = match.group(1), match.group(2), match.group(3)
            heading = strip_inline(heading_html)
            if level == "2":
                parent_h2 = heading
                section = heading
            else:
                section = f"{parent_h2} › {heading}" if parent_h2 else heading
            end = matches[index + 1].start() if index + 1 < len(matches) else len(page.body)
            text = search_text(page.body[match.end() : end])
            add(section, text, f"{page.out}#{anchor}")
    else:
        add("", search_text(page.body), page.out)
    return entries


# ---------------------------------------------------------------------------
# TOC / navigation
# ---------------------------------------------------------------------------


def render_toc(tokens: list[dict]) -> str:
    if not tokens:
        return ""
    parts = ['<ul class="toc-list">']
    for token in tokens:
        name = strip_inline(token.get("name", ""))
        anchor = token.get("id", "")
        depth = int(token.get("level", 2))
        parts.append(f'<li class="toc-item toc-depth-{depth}">')
        parts.append(f'<a class="toc-link" href="#{html.escape(anchor)}">{html.escape(name)}</a>')
        if token.get("children"):
            parts.append(render_toc(token["children"]))
        parts.append("</li>")
    parts.append("</ul>")
    return "".join(parts)


def nav_label(page: Page) -> str:
    label = LABEL_OVERRIDES.get(page.rel, page.title)
    if page.rel.startswith("errors/err"):
        label = page.title[4:] if page.title.startswith("ERR-") else page.title
    return label


def ordered_nav(pages: dict[str, Page]) -> list[tuple[str, list[Page]]]:
    groups: list[tuple[str, list[Page]]] = []
    for key, rels in NAV_GROUPS:
        if key == "errors":
            error_pages = sorted(
                (p for p in pages.values() if p.rel.startswith("errors/err")),
                key=lambda p: p.rel,
            )
            items = [pages["errors/index.md"]] + error_pages
        else:
            items = [pages[rel] for rel in rels if rel in pages]
        groups.append((key, items))

    assigned = {page.rel for _, items in groups for page in items}
    leftovers = sorted(
        (p for p in pages.values() if p.rel not in assigned), key=lambda p: p.rel
    )
    if leftovers:
        groups.append(("meta", leftovers))
    return groups


def render_sidebar(
    current: Page | None,
    groups: list[tuple[str, list[Page]]],
    page_count: int,
    root: str,
) -> str:
    current_group = current.group if current else ""
    parts = ['<nav class="sidebar-nav" aria-label="Documentation">']
    home_active = " is-active" if current is None else ""
    parts.append(
        f'<a class="nav-home{home_active}" href="{root}index.html">'
        '<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M3 9.5 10 3l7 6.5V17h-5v-4H8v4H3Z"/></svg>'
        "<span>Home</span></a>"
    )
    for key, items in groups:
        if not items:
            continue
        info = GROUP_INFO.get(key, {"label": key.title(), "blurb": ""})
        open_attr = " open" if (current_group == key or key in {"guides", "language", "reference"}) else ""
        parts.append(
            f'<details class="nav-group" data-group="{html.escape(key)}"{open_attr}>'
        )
        count = len(items) - 1 if key == "errors" else len(items)
        parts.append(
            '<summary class="nav-group-head">'
            f'<span>{html.escape(info["label"])}</span>'
            f'<span class="nav-count">{count}</span>'
            '<svg class="nav-chevron" viewBox="0 0 16 16" aria-hidden="true"><path d="m5 6 3 3 3-3"/></svg>'
            "</summary>"
        )
        parts.append('<div class="nav-items">')
        for page in items:
            active = current is not None and page.rel == current.rel
            classes = "nav-link is-active" if active else "nav-link"
            aria = ' aria-current="page"' if active else ""
            parts.append(
                f'<a class="{classes}" href="{root}{html.escape(page.out)}"{aria}>'
                f'<span>{html.escape(nav_label(page))}</span>'
                "</a>"
            )
        parts.append("</div></details>")
    parts.append("</nav>")
    parts.append(
        '<div class="sidebar-foot">'
        f'<span class="status-dot"></span><span>{page_count} pages</span>'
        '<span class="sidebar-sep">·</span><span>from <code>docs/</code></span>'
        "</div>"
    )
    return "".join(parts)


def render_chips(page: Page) -> str:
    chips: list[str] = []
    doc_id = page.meta.get("doc-id")
    if doc_id and doc_id != page.title:
        chips.append(f'<span class="chip chip-id">{html.escape(doc_id)}</span>')
    status = page.meta.get("status")
    if status:
        chips.append(
            f'<span class="chip chip-status" data-status="{html.escape(status)}">{html.escape(status)}</span>'
        )
    phase = page.meta.get("phase")
    if phase:
        chips.append(f'<span class="chip"><span class="chip-key">phase</span> {html.escape(phase)}</span>')
    return "".join(chips)


def render_breadcrumb(
    page: Page, group_label: str, root: str, group_home: Page | None
) -> str:
    if group_home is not None and group_home.rel != page.rel:
        group_html = (
            f'<a href="{root}{html.escape(group_home.out)}">'
            f"{html.escape(group_label)}</a>"
        )
    else:
        group_html = f"<span>{html.escape(group_label)}</span>"
    return (
        '<nav class="breadcrumb" aria-label="Breadcrumb">'
        f'<a href="{root}index.html">Docs</a>'
        '<span class="crumb-sep">/</span>'
        f"{group_html}"
        '<span class="crumb-sep">/</span>'
        f'<span aria-current="page">{html.escape(page.title)}</span>'
        "</nav>"
    )


def render_pager(
    current: Page, groups: list[tuple[str, list[Page]]], root: str
) -> str:
    flat = [page for _, items in groups for page in items]
    try:
        index = next(i for i, page in enumerate(flat) if page.rel == current.rel)
    except StopIteration:
        return ""
    prev_page = flat[index - 1] if index > 0 else None
    next_page = flat[index + 1] if index + 1 < len(flat) else None

    prev_html = (
        f'<a class="pager-card pager-prev" href="{root}{html.escape(prev_page.out)}">'
        '<span class="pager-label">Previous</span>'
        f'<strong>{html.escape(nav_label(prev_page))}</strong></a>'
        if prev_page
        else '<span class="pager-card pager-empty"></span>'
    )
    next_html = (
        f'<a class="pager-card pager-next" href="{root}{html.escape(next_page.out)}">'
        '<span class="pager-label">Next</span>'
        f'<strong>{html.escape(nav_label(next_page))}</strong></a>'
        if next_page
        else '<span class="pager-card pager-empty"></span>'
    )
    return f'<nav class="pager" aria-label="Page navigation">{prev_html}{next_html}</nav>'


# ---------------------------------------------------------------------------
# HTML shell
# ---------------------------------------------------------------------------


def absolute_url(page_path: str) -> str:
    if page_path in ("", "index.html"):
        return f"{SITE_URL}/"
    return f"{SITE_URL}/{page_path.lstrip('/')}"


def head(
    title: str,
    description: str,
    root: str,
    page_path: str,
    theme: bool = True,
    canonical: str | None = None,
    noindex: bool = False,
) -> str:
    theme_script = (
        "<script>(function(){try{"
        "var forced=new URLSearchParams(location.search).get('theme');"
        "var t=(forced==='light'||forced==='dark')?forced:localStorage.getItem('kovy-theme');"
        "if(!t)t=window.matchMedia('(prefers-color-scheme: light)').matches?'light':'dark';"
        "document.documentElement.dataset.theme=t;"
        "}catch(e){document.documentElement.dataset.theme='dark'}})();</script>"
        if theme
        else ""
    )
    og_image = f"{SITE_URL}/assets/og-image.png"
    meta = [
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        f"<title>{html.escape(title)}</title>",
        f'<meta name="description" content="{html.escape(description)}">',
        '<meta name="color-scheme" content="dark light">',
        f'<meta name="generator" content="Kovy docs {html.escape(DOCS_VERSION)}">',
        '<meta name="theme-color" content="#0a0c10" media="(prefers-color-scheme: dark)">',
        '<meta name="theme-color" content="#faf8f4" media="(prefers-color-scheme: light)">',
        '<meta property="og:site_name" content="Kovy docs">',
        '<meta property="og:type" content="website">',
        f'<meta property="og:title" content="{html.escape(title)}">',
        f'<meta property="og:description" content="{html.escape(description)}">',
        f'<meta property="og:image" content="{html.escape(og_image)}">',
        '<meta property="og:image:width" content="1200">',
        '<meta property="og:image:height" content="630">',
        '<meta name="twitter:card" content="summary_large_image">',
        f'<meta name="twitter:title" content="{html.escape(title)}">',
        f'<meta name="twitter:description" content="{html.escape(description)}">',
        f'<meta name="twitter:image" content="{html.escape(og_image)}">',
    ]
    if canonical:
        meta.append(f'<link rel="canonical" href="{html.escape(canonical)}">')
        meta.append(f'<meta property="og:url" content="{html.escape(canonical)}">')
    if noindex:
        meta.append('<meta name="robots" content="noindex, follow">')
    meta.extend(
        [
            f'<link rel="icon" href="{root}assets/favicon.png" type="image/png">',
            f'<link rel="apple-touch-icon" href="{root}assets/favicon.png">',
        ]
    )
    if theme_script:
        meta.append(theme_script)
    meta.extend(
        [
            f'<link rel="stylesheet" href="{root}assets/style.css?v={html.escape(ASSET_VERSION)}">',
            f'<script defer src="{root}assets/search-index.js?v={html.escape(ASSET_VERSION)}"></script>',
            f'<script defer src="{root}assets/app.js?v={html.escape(ASSET_VERSION)}"></script>',
        ]
    )
    return (
        "<!doctype html>\n"
        f'<html lang="en" data-root="{root}" data-page="{html.escape(page_path)}">\n'
        "<head>\n"
        + "\n".join(meta)
        + "\n</head>\n"
    )


def header(root: str) -> str:
    return (
        '<header class="topbar">'
        '<div class="topbar-inner">'
        '<button class="icon-button menu-toggle" type="button" aria-label="Open navigation" aria-expanded="false">'
        '<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M3 6h14M3 10h14M3 14h14"/></svg>'
        "</button>"
        f'<a class="brand" href="{root}index.html" aria-label="Kovy docs home">'
        '<span class="brand-mark" aria-hidden="true">'
        f'<img class="brand-logo brand-logo-light" src="{root}assets/logo-light.png" alt="">'
        f'<img class="brand-logo brand-logo-dark" src="{root}assets/logo-dark.png" alt="">'
        "</span>"
        '<span class="brand-name">kovy</span>'
        '<span class="brand-badge">docs</span>'
        "</a>"
        '<div class="topbar-spacer"></div>'
        '<button class="search-trigger" type="button" data-open-search aria-label="Search documentation">'
        '<svg viewBox="0 0 20 20" aria-hidden="true"><circle cx="9" cy="9" r="5.5"/><path d="m13 13 4 4"/></svg>'
        '<span class="search-trigger-text">Search docs</span>'
        '<kbd>Ctrl K</kbd>'
        "</button>"
        '<div class="topbar-actions">'
        f'<a class="icon-button github-link" href="{REPO_URL}" target="_blank" rel="noreferrer" aria-label="Kovy on GitHub">'
        '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2a10 10 0 0 0-3.16 19.49c.5.09.68-.22.68-.48v-1.7c-2.78.6-3.37-1.18-3.37-1.18-.45-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.61.07-.61 1 .07 1.53 1.03 1.53 1.03.9 1.53 2.34 1.09 2.91.83.09-.65.35-1.09.64-1.34-2.22-.25-4.55-1.11-4.55-4.94 0-1.09.39-1.98 1.03-2.68-.1-.25-.45-1.27.1-2.64 0 0 .84-.27 2.75 1.02A9.56 9.56 0 0 1 12 6.8c.85 0 1.71.11 2.51.34 1.91-1.29 2.75-1.02 2.75-1.02.55 1.37.2 2.39.1 2.64.64.7 1.03 1.59 1.03 2.68 0 3.84-2.34 4.68-4.57 4.93.36.31.68.92.68 1.85v2.75c0 .27.18.58.69.48A10 10 0 0 0 12 2Z"/></svg>'
        "</a>"
        '<button class="icon-button theme-toggle" type="button" aria-label="Toggle colour theme" title="Toggle colour theme">'
        '<svg class="icon-sun" viewBox="0 0 20 20" aria-hidden="true"><circle cx="10" cy="10" r="4"/><path d="M10 1.5v2M10 16.5v2M1.5 10h2M16.5 10h2M3.99 3.99l1.42 1.42M14.59 14.59l1.42 1.42M16.01 3.99l-1.42 1.42M5.41 14.59l-1.42 1.42"/></svg>'
        '<svg class="icon-moon" viewBox="0 0 20 20" aria-hidden="true"><path d="M16.5 12.2A7 7 0 0 1 7.8 3.5a7 7 0 1 0 8.7 8.7Z"/></svg>'
        "</button>"
        "</div></div></header>"
    )


def search_overlay(root: str) -> str:
    return (
        '<div class="search-overlay" id="searchOverlay" hidden>'
        '<div class="search-backdrop" data-close-search></div>'
        '<div class="search-panel" role="dialog" aria-modal="true" aria-labelledby="searchTitle">'
        '<h2 class="sr-only" id="searchTitle">Search documentation</h2>'
        '<div class="search-input-wrap">'
        '<svg viewBox="0 0 20 20" aria-hidden="true"><circle cx="9" cy="9" r="5.5"/><path d="m13 13 4 4"/></svg>'
        '<input id="searchInput" type="search" placeholder="Search pages, rules, errors…" autocomplete="off" spellcheck="false" aria-controls="searchResults">'
        '<button class="search-close" type="button" data-close-search aria-label="Close search">Esc</button>'
        "</div>"
        '<div class="search-filters" role="toolbar" aria-label="Filter search results">'
        '<button class="search-filter is-active" type="button" data-search-group="all" aria-pressed="true">All</button>'
        '<button class="search-filter" type="button" data-search-group="Guides" aria-pressed="false">Guides</button>'
        '<button class="search-filter" type="button" data-search-group="Language" aria-pressed="false">Language</button>'
        '<button class="search-filter" type="button" data-search-group="Reference" aria-pressed="false">Reference</button>'
        '<button class="search-filter" type="button" data-search-group="Errors" aria-pressed="false">Errors</button>'
        '<button class="search-filter" type="button" data-search-group="Internals" aria-pressed="false">Internals</button>'
        '<button class="search-filter" type="button" data-search-group="Meta" aria-pressed="false">Meta</button>'
        "</div>"
        '<div class="search-results" id="searchResults" role="listbox" aria-label="Search results" aria-live="polite"></div>'
        '<div class="search-foot">'
        '<span><kbd>↑</kbd><kbd>↓</kbd> navigate</span>'
        '<span><kbd>↵</kbd> open</span>'
        '<span><kbd>esc</kbd> close</span>'
        "</div></div></div>"
    )


def footer(page: Page | None, page_count: int) -> str:
    edit = ""
    if page is not None:
        edit = (
            f'<a class="foot-link" href="{REPO_URL}/blob/{BRANCH}/docs/{page.rel}" target="_blank" rel="noreferrer">'
            "Edit this page on GitHub ↗</a>"
        )
    else:
        edit = (
            f'<a class="foot-link" href="{REPO_URL}" target="_blank" rel="noreferrer">'
            "Kovy on GitHub ↗</a>"
        )
    return (
        '<footer class="site-foot">'
        f'<span>Built from <code>docs/</code></span>'
        '<span class="foot-dot">·</span>'
        f"<span>{page_count} pages</span>"
        '<span class="foot-dot">·</span>'
        f"<span>v{DOCS_VERSION} · {BUILD_DATE}</span>"
        '<span class="foot-dot">·</span>'
        f"{edit}"
        "</footer>"
    )


def article_page(page: Page, groups: list[tuple[str, list[Page]]], pages: dict[str, Page]) -> str:
    root = page.root
    group_label = GROUP_INFO.get(page.group, {}).get("label", "Docs")
    group_items = next((items for key, items in groups if key == page.group), [])
    group_home = group_items[0] if group_items else None
    toc_html = render_toc(page.toc_tokens)
    toc_aside = (
        f'<aside class="toc" aria-label="On this page"><p class="toc-title">On this page</p>{toc_html}</aside>'
        if toc_html
        else ""
    )
    toc_mobile = (
        f'<details class="toc-mobile"><summary>On this page</summary>{toc_html}</details>'
        if toc_html
        else ""
    )
    body = rewrite_links(page, pages)
    chips = render_chips(page)
    pager = render_pager(page, groups, root)
    shell_class = "content-shell" if toc_html else "content-shell no-toc"

    content = (
        f'<div class="{shell_class}">'
        '<article class="doc" id="main-content" tabindex="-1">'
        f'{render_breadcrumb(page, group_label, root, group_home)}'
        f'<header class="doc-head"><p class="doc-kicker">{html.escape(group_label)}</p>'
        f"<h1>{html.escape(page.title)}</h1>"
        f'<div class="doc-chips">{chips}</div></header>'
        f"{toc_mobile}"
        f'<div class="doc-body">{body}</div>'
        f"{pager}"
        '<div class="doc-tools">'
        f'<a class="foot-link" href="{REPO_URL}/blob/{BRANCH}/docs/{page.rel}" target="_blank" rel="noreferrer">Edit this page on GitHub ↗</a>'
        "</div>"
        "</article>"
        f"{toc_aside}"
        "</div>"
    )

    return (
        head(
            f"{page.title} · Kovy docs",
            page.description,
            root,
            page.out,
            canonical=absolute_url(page.out),
        )
        + '<body class="doc-page">'
        + '<a class="skip-link" href="#main-content">Skip to content</a>'
        + header(root)
        + '<div class="page-frame">'
        + '<div class="sidebar-backdrop" data-close-sidebar></div>'
        + f'<aside class="sidebar">{render_sidebar(page, groups, len(pages), root)}</aside>'
        + content
        + "</div>"
        + search_overlay(root)
        + footer(page, len(pages))
        + "</body></html>"
    )


def home_page(groups: list[tuple[str, list[Page]]], pages: dict[str, Page], example_count: int) -> str:
    page_count = len(pages)
    error_count = sum(1 for p in pages.values() if p.rel.startswith("errors/err"))
    hero_code = render_code_block(
        "int add(int a, int b):\n  return a + b\n\nint result = add(1, 2)",
        "kovy",
        None,
    )

    def group_card(key: str, title: str, text: str, page_rel: str, links: list[str]) -> str:
        links_html = "".join(
            f'<a class="card-link" href="{pages[rel].out}">{html.escape(nav_label(pages[rel]))}</a>'
            for rel in links
            if rel in pages
        )
        return (
            '<article class="feature-card">'
            f'<div class="feature-top"><span class="feature-eyebrow">{html.escape(GROUP_INFO[key]["label"])}</span></div>'
            f'<h3><a href="{pages[page_rel].out}">{html.escape(title)}</a></h3>'
            f"<p>{html.escape(text)}</p>"
            f'<div class="card-links">{links_html}</div>'
            "</article>"
        )

    cards = "".join(
        [
            group_card(
                "guides",
                "Learn the language",
                "Start with complete programs, then move through syntax and semantics.",
                "guides/hello-world.md",
                ["guides/hello-world.md", "language/overview.md", "language/grammar.md"],
            ),
            group_card(
                "reference",
                "Look up a rule",
                "Keywords, tokens, operators, CLI commands, precedence and compatibility tables.",
                "reference/keywords.md",
                [
                    "reference/keywords.md",
                    "reference/cli.md",
                    "reference/operators.md",
                    "reference/syntax-index.md",
                ],
            ),
            group_card(
                "errors",
                "Fix a diagnostic",
                "Every ErrorKind, its exact message, emitters and reproducers.",
                "errors/index.md",
                ["errors/index.md", "reference/error-index.md", "language/pipeline.md"],
            ),
            group_card(
                "internals",
                "Go deeper",
                "AST, semantic analysis, type model, Nim generation and runtime helpers.",
                "internals/ast.md",
                ["internals/ast.md", "internals/sema.md", "internals/nimgen.md"],
            ),
        ]
    )

    content = f"""
<div class="home">
  <section class="hero">
    <div class="hero-copy">
      <p class="hero-eyebrow"><span class="status-dot"></span>Kovy language reference <span class="dot-sep">·</span> v0.1</p>
      <h1>A small language,<br><span class="accent">documented precisely.</span></h1>
      <p class="hero-lead">Kovy is a statically typed, indentation-sensitive language implemented in Nim. This reference tracks the compiler as it is: syntax, semantics, generated-code behaviour and every diagnostic.</p>
      <div class="hero-actions">
        <a class="button button-primary" href="guides/hello-world.html">Start with hello world <span aria-hidden="true">→</span></a>
        <a class="button button-ghost" href="language/grammar.html">Browse the grammar</a>
      </div>
      <button class="home-search" type="button" data-open-search>
        <svg viewBox="0 0 20 20" aria-hidden="true"><circle cx="9" cy="9" r="5.5"/><path d="m13 13 4 4"/></svg>
        <span>Search pages, rules, errors…</span>
        <kbd>Ctrl K</kbd>
      </button>
    </div>
    <div class="hero-visual">
      <div class="hero-code-label">example.kovy</div>
      {hero_code}
      <div class="hero-glow"></div>
    </div>
  </section>

  <section class="stats" aria-label="Documentation statistics">
    <div class="stat"><strong>{page_count}</strong><span>reference pages</span></div>
    <div class="stat"><strong>{error_count}</strong><span>diagnostics</span></div>
    <div class="stat"><strong>{example_count}</strong><span>Kovy examples</span></div>
    <div class="stat"><strong>5</strong><span>compiler stages</span></div>
  </section>

  <section class="home-section">
    <div class="section-head">
      <h2>Find your way in</h2>
      <p>Four paths through the reference, depending on what you need right now.</p>
    </div>
    <div class="feature-grid">{cards}</div>
  </section>

  <section class="home-section start-strip">
    <div>
      <p class="section-kicker">First read</p>
      <h2>Language overview</h2>
      <p>The shortest route to the shape of the language: types, program structure, memory model and the compilation pipeline.</p>
    </div>
    <a class="button button-ghost" href="language/overview.html">Open overview <span aria-hidden="true">→</span></a>
  </section>
</div>
"""

    return (
        head(
            "Kovy language docs",
            "Kovy language reference: syntax, semantics and every diagnostic.",
            "",
            "index.html",
            canonical=absolute_url("index.html"),
        )
        + '<body class="home-page">'
        + '<a class="skip-link" href="#main-content">Skip to content</a>'
        + header("")
        + '<div class="page-frame">'
        + '<div class="sidebar-backdrop" data-close-sidebar></div>'
        + f'<aside class="sidebar">{render_sidebar(None, groups, page_count, "")}</aside>'
        + '<div class="home-shell" id="main-content" tabindex="-1">'
        + content
        + "</div>"
        + "</div>"
        + search_overlay("")
        + footer(None, page_count)
        + "</body></html>"
    )


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------


def not_found_page(groups: list[tuple[str, list[Page]]], page_count: int) -> str:
    content = """
<div class="home-shell not-found" id="main-content" tabindex="-1">
  <section class="not-found-card">
    <p class="section-kicker">404</p>
    <h1>This page does not exist.</h1>
    <p class="hero-lead">The link may be outdated, or the page was renamed. Try searching the reference or start from the home page.</p>
    <div class="hero-actions">
      <a class="button button-primary" href="index.html">Back to the docs <span aria-hidden="true">→</span></a>
      <button class="button button-ghost" type="button" data-open-search>Search the reference</button>
    </div>
    <div class="not-found-links">
      <a href="guides/hello-world.html">Hello world</a>
      <a href="language/overview.html">Language overview</a>
      <a href="reference/keywords.html">Keyword reference</a>
      <a href="errors/index.html">Error catalogue</a>
    </div>
  </section>
</div>
"""
    return (
        head(
            "Page not found · Kovy docs",
            "This page does not exist in the Kovy documentation.",
            "",
            "404.html",
            canonical=None,
            noindex=True,
        )
        + '<body class="home-page not-found-page">'
        + '<a class="skip-link" href="#main-content">Skip to content</a>'
        + header("")
        + '<div class="page-frame">'
        + '<div class="sidebar-backdrop" data-close-sidebar></div>'
        + f'<aside class="sidebar">{render_sidebar(None, groups, page_count, "")}</aside>'
        + content
        + "</div>"
        + search_overlay("")
        + footer(None, page_count)
        + "</body></html>"
    )


def sitemap_xml(pages: dict[str, Page]) -> str:
    urls = [absolute_url("index.html")] + [absolute_url(page.out) for page in pages.values()]
    lastmod = f"<lastmod>{BUILD_DATE}</lastmod>"
    body = "".join(f"<url><loc>{html.escape(url)}</loc>{lastmod}</url>" for url in urls)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        + body
        + "</urlset>\n"
    )


def robots_txt() -> str:
    return (
        "User-agent: *\n"
        "Allow: /\n"
        f"Sitemap: {SITE_URL}/sitemap.xml\n"
    )


def copy_assets(project: Path, out_dir: Path) -> None:
    target = out_dir / "assets"
    target.mkdir(parents=True, exist_ok=True)
    for src in (project / "assets").iterdir():
        if src.is_file():
            shutil.copy2(src, target / src.name)


def main() -> None:
    global SITE_URL, DOCS_VERSION, BUILD_DATE, ASSET_VERSION

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--docs", type=Path, default=DEFAULT_DOCS)
    parser.add_argument("--out", type=Path, default=PROJECT_DIR / "site")
    parser.add_argument(
        "--base-url",
        default=os.environ.get("KOVY_SITE_URL", DEFAULT_SITE_URL),
        help="absolute URL where the site will be published",
    )
    parser.add_argument(
        "--version",
        default=os.environ.get("KOVY_DOCS_VERSION", DOCS_VERSION),
        help="documentation version shown in page metadata",
    )
    parser.add_argument(
        "--build-date",
        default=os.environ.get("KOVY_BUILD_DATE") or BUILD_DATE,
        help="build date shown in page metadata (YYYY-MM-DD)",
    )
    args = parser.parse_args()

    SITE_URL = (args.base_url or DEFAULT_SITE_URL).rstrip("/")
    DOCS_VERSION = args.version
    BUILD_DATE = args.build_date

    docs: Path = args.docs.resolve()
    out_dir: Path = args.out.resolve()
    if not docs.is_dir():
        raise SystemExit(f"docs directory not found: {docs}")

    if not os.environ.get("KOVY_ASSET_VERSION") and not os.environ.get("GITHUB_SHA"):
        ASSET_VERSION = compute_asset_version(docs)

    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    pages: dict[str, Page] = {}
    for src in sorted(docs.rglob("*.md")):
        page = load_page(src, docs)
        pages[page.rel] = page

    groups = ordered_nav(pages)

    for page in pages.values():
        target = out_dir / page.out
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(article_page(page, groups, pages), encoding="utf-8")

    example_count = sum(
        1
        for page in pages.values()
        for line in page.src.read_text(encoding="utf-8").splitlines()
        if line.strip() == "```kovy"
    )

    (out_dir / "index.html").write_text(
        home_page(groups, pages, example_count), encoding="utf-8"
    )
    (out_dir / "404.html").write_text(
        not_found_page(groups, len(pages)), encoding="utf-8"
    )
    (out_dir / "sitemap.xml").write_text(sitemap_xml(pages), encoding="utf-8")
    (out_dir / "robots.txt").write_text(robots_txt(), encoding="utf-8")
    (out_dir / ".nojekyll").write_text("", encoding="utf-8")

    search_entries: list[dict] = []
    for page in pages.values():
        search_entries.extend(page.entries)
    search_entries.sort(key=lambda e: (e["g"], e["t"], e["u"]))
    (out_dir / "assets").mkdir(parents=True, exist_ok=True)
    (out_dir / "assets" / "search-index.js").write_text(
        "window.KOVY_SEARCH_INDEX="
        + json.dumps(search_entries, ensure_ascii=False, separators=(",", ":"))
        + ";\n",
        encoding="utf-8",
    )

    copy_assets(PROJECT_DIR, out_dir)

    print(f"Built {len(pages)} pages + home + 404 into {out_dir}")
    print(f"Search entries: {len(search_entries)}")
    print(f"Site URL: {SITE_URL}")
    print(f"Version: {DOCS_VERSION} · build date: {BUILD_DATE}")


if __name__ == "__main__":
    main()