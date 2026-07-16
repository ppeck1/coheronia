#!/usr/bin/env python3
"""Fail when a repo-local link in the public wiki resolves to no file."""
from __future__ import annotations

import re
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[2]
WIKI = ROOT / "docs" / "wiki"
REFERENCE_STEMS = [
    "VARIABLE_MATRIX",
    "ITEM_AND_RECIPE_MATRIX",
    "ITEM_GRAPH",
    "IMAGE_INVENTORY_MATRIX",
    "ASSET_ROADMAP",
    "UI_ASSET_GAPS",
]
MARKDOWN_LINK = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
HTML_LINK = re.compile(r"(?:href|src)=[\"']([^\"']+)[\"']", re.IGNORECASE)


def sources() -> list[Path]:
    paths = sorted(
        path for path in WIKI.rglob("*")
        if path.is_file() and path.suffix.lower() in {".md", ".html"}
    )
    for stem in REFERENCE_STEMS:
        for suffix in (".md", ".html"):
            path = ROOT / "docs" / f"{stem}{suffix}"
            if path.is_file():
                paths.append(path)
    return paths


def local_target(source: Path, raw_target: str) -> Path | None:
    target = raw_target.strip().strip("<>")
    if not target or target.startswith("#"):
        return None
    parts = urlsplit(target)
    if parts.scheme or parts.netloc:
        return None
    path_text = unquote(parts.path)
    if not path_text:
        return None
    if path_text.startswith("/"):
        return ROOT / path_text.lstrip("/")
    return source.parent / path_text


def main() -> int:
    checked_links = 0
    failures: list[str] = []
    checked_sources = sources()
    for source in checked_sources:
        text = source.read_text(encoding="utf-8")
        pattern = MARKDOWN_LINK if source.suffix.lower() == ".md" else HTML_LINK
        for raw_target in pattern.findall(text):
            target = local_target(source, raw_target)
            if target is None:
                continue
            checked_links += 1
            if not target.exists():
                failures.append(
                    f"{source.relative_to(ROOT).as_posix()}: {raw_target}"
                )
    if failures:
        print(f"FAIL wiki links: {len(failures)} missing target(s)")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print(
        f"PASS wiki links: {checked_links} local links across "
        f"{len(checked_sources)} Markdown/HTML files"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
