#!/usr/bin/env python3
"""Validate the generated Kovy documentation site.

Checks that every generated page has the expected metadata, that internal
links and assets resolve, that the search index points at real anchors, and
that the sitemap/robots/404 files are present.

Usage:
    python3 check_site.py [site-directory]
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote

REQUIRED_FILES = ["index.html", "404.html", "sitemap.xml", "robots.txt", ".nojekyll"]
LINK_ATTRS = ("href", "src")
EXTERNAL_PREFIXES = ("http://", "https://", "mailto:", "tel:", "data:", "//")


def fail(problems: list[str], message: str) -> None:
    problems.append(message)


def main() -> int:
    site = Path(sys.argv[1] if len(sys.argv) > 1 else "site").resolve()
    if not site.is_dir():
        print(f"FAIL: site directory not found: {site}")
        return 1

    problems: list[str] = []
    pages = sorted(site.rglob("*.html"))

    for name in REQUIRED_FILES:
        if not (site / name).is_file():
            fail(problems, f"missing required file: {name}")

    texts: dict[Path, str] = {page: page.read_text(encoding="utf-8") for page in pages}
    local_refs = 0

    for page, text in texts.items():
        rel = page.relative_to(site).as_posix()

        for attr in LINK_ATTRS:
            for raw in re.findall(rf'{attr}="([^"]+)"', text):
                value = raw.strip()
                if not value or value.startswith(EXTERNAL_PREFIXES):
                    continue
                if value.startswith("#"):
                    continue
                path_part = unquote(value.split("#", 1)[0].split("?", 1)[0])
                if not path_part:
                    continue
                local_refs += 1
                target = (page.parent / path_part).resolve()
                if not target.exists():
                    fail(problems, f"{rel}: broken {attr} -> {value}")

        if rel == "404.html":
            if 'content="noindex, follow"' not in text and 'content="noindex"' not in text:
                fail(problems, "404.html: missing noindex robots meta")
            if 'rel="canonical"' in text:
                fail(problems, "404.html: must not advertise a canonical URL")
        else:
            if 'rel="canonical"' not in text:
                fail(problems, f"{rel}: missing canonical URL")
            if 'name="generator"' not in text:
                fail(problems, f"{rel}: missing generator meta")

        if 'property="og:image"' not in text:
            fail(problems, f"{rel}: missing Open Graph image")
        if 'rel="icon"' not in text:
            fail(problems, f"{rel}: missing favicon")

    # Search index: every entry must point at an existing page and anchor.
    index_path = site / "assets" / "search-index.js"
    search_entries = 0
    if not index_path.is_file():
        fail(problems, "missing assets/search-index.js")
    else:
        source = index_path.read_text(encoding="utf-8")
        try:
            payload = source[source.index("=") + 1 : source.rindex(";")]
            entries = json.loads(payload)
        except (ValueError, json.JSONDecodeError):
            entries = []
            fail(problems, "assets/search-index.js is not valid JSON")
        if isinstance(entries, list):
            search_entries = len(entries)
            for entry in entries:
                url = entry.get("u", "")
                page_part, _, fragment = url.partition("#")
                target = site / page_part
                if not target.is_file():
                    fail(problems, f"search: missing page for {url}")
                    continue
                if fragment and f'id="{fragment}"' not in texts.get(
                    target.resolve(), target.read_text(encoding="utf-8")
                ):
                    fail(problems, f"search: missing anchor for {url}")

    # Sitemap should list the home page and every rendered document.
    sitemap_path = site / "sitemap.xml"
    if sitemap_path.is_file():
        sitemap = sitemap_path.read_text(encoding="utf-8")
        locs = re.findall(r"<loc>([^<]+)</loc>", sitemap)
        expected = len(pages) - (1 if (site / "404.html").is_file() else 0)
        if len(locs) != expected:
            fail(
                problems,
                f"sitemap: {len(locs)} URLs for {expected} indexable pages",
            )
        if any(loc.rstrip("/").endswith("/404.html") for loc in locs):
            fail(problems, "sitemap: 404 page must not be listed")
        if not all(loc.startswith(("http://", "https://")) for loc in locs):
            fail(problems, "sitemap: URLs must be absolute")
    robots_path = site / "robots.txt"
    if robots_path.is_file() and "sitemap.xml" not in robots_path.read_text(encoding="utf-8"):
        fail(problems, "robots.txt: missing sitemap reference")

    print(f"site: {site}")
    print(f"pages: {len(pages)}")
    print(f"local links/assets: {local_refs}")
    print(f"search entries: {search_entries}")

    if problems:
        print(f"\n{len(problems)} problem(s):")
        for problem in problems[:40]:
            print(f"  - {problem}")
        if len(problems) > 40:
            print(f"  … and {len(problems) - 40} more")
        return 1

    print("\nOK: site is consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())