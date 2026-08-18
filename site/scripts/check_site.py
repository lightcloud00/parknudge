#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []
        self.images: list[tuple[str, bool]] = []
        self.title = ""
        self.description = ""
        self.h1_count = 0
        self.canonical = ""
        self._in_title = False
        self._json_ld = False
        self._json_parts: list[str] = []
        self.json_documents: list[object] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if tag == "a" and values.get("href"):
            self.links.append(values["href"] or "")
        if tag == "img" and values.get("src"):
            self.images.append((values["src"] or "", "alt" in values))
        if tag == "title":
            self._in_title = True
        if tag == "h1":
            self.h1_count += 1
        if tag == "meta" and values.get("name") == "description":
            self.description = values.get("content") or ""
        if tag == "link" and values.get("rel") == "canonical":
            self.canonical = values.get("href") or ""
        if tag == "script" and values.get("type") == "application/ld+json":
            self._json_ld = True
            self._json_parts = []

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self._in_title = False
        if tag == "script" and self._json_ld:
            self.json_documents.append(json.loads("".join(self._json_parts)))
            self._json_ld = False

    def handle_data(self, data: str) -> None:
        if self._in_title:
            self.title += data
        if self._json_ld:
            self._json_parts.append(data)


def local_target(page: Path, reference: str, root: Path) -> Path | None:
    parsed = urlsplit(reference)
    if parsed.scheme or parsed.netloc or reference.startswith("#") or reference.startswith("mailto:"):
        return None
    target = (page.parent / parsed.path).resolve()
    if parsed.path.endswith("/") or target.is_dir():
        target = target / "index.html"
    if root not in target.parents and target != root:
        raise ValueError(f"path escapes site root: {reference}")
    return target


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    pages = sorted(root.rglob("*.html"))
    errors: list[str] = []
    if len(pages) < 8:
        errors.append(f"expected at least 8 pages, found {len(pages)}")

    for page in pages:
        parser = PageParser()
        try:
            parser.feed(page.read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"{page.relative_to(root)}: parse error: {exc}")
            continue
        label = str(page.relative_to(root))
        if not parser.title.strip(): errors.append(f"{label}: missing title")
        if not (50 <= len(parser.description) <= 165): errors.append(f"{label}: description length {len(parser.description)}")
        if parser.h1_count != 1: errors.append(f"{label}: expected one h1, found {parser.h1_count}")
        if not parser.canonical.startswith("https://parknudge.app/"): errors.append(f"{label}: candidate canonical missing")
        for src, has_alt in parser.images:
            if not has_alt: errors.append(f"{label}: image missing alt attribute: {src}")
        for reference in parser.links + [src for src, _ in parser.images]:
            try:
                target = local_target(page, reference, root)
            except ValueError as exc:
                errors.append(f"{label}: {exc}")
                continue
            if target is not None and not target.exists():
                errors.append(f"{label}: broken local reference {reference}")

    homepage = PageParser()
    homepage.feed((root / "index.html").read_text(encoding="utf-8"))
    types = {doc.get("@type") for doc in homepage.json_documents if isinstance(doc, dict)}
    if not {"SoftwareApplication", "FAQPage"}.issubset(types):
        errors.append("index.html: missing SoftwareApplication or FAQPage JSON-LD")
    if not (root / "robots.txt").exists() or not (root / "sitemap.xml").exists():
        errors.append("robots.txt or sitemap.xml missing")

    if errors:
        print("Site checks failed:")
        for error in errors: print(f"- {error}")
        return 1
    print(f"Site checks passed: {len(pages)} HTML pages, metadata, JSON-LD, and local links verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
