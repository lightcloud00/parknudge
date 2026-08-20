#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit
from xml.etree import ElementTree


CANONICAL_ORIGIN = "https://parknudge.app"
GUIDE_SCHEMA = {
    "find-my-parked-car/index.html": {"Article", "BreadcrumbList"},
    "parking-meter-reminder/index.html": {"Article", "BreadcrumbList"},
    "parking-garage-tips/index.html": {"Article", "BreadcrumbList"},
}


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []
        self.images: list[tuple[str, bool]] = []
        self.title = ""
        self.description = ""
        self.h1_count = 0
        self.canonical = ""
        self.html_lang = ""
        self.has_main = False
        self.has_primary_nav = False
        self.has_skip_link = False
        self.meta_names: dict[str, str] = {}
        self.meta_properties: dict[str, str] = {}
        self._in_title = False
        self._json_ld = False
        self._json_parts: list[str] = []
        self.json_documents: list[object] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if tag == "html":
            self.html_lang = values.get("lang") or ""
        if tag == "a" and values.get("href"):
            self.links.append(values["href"] or "")
            if "skip-link" in (values.get("class") or "").split():
                self.has_skip_link = True
        if tag == "img" and values.get("src"):
            self.images.append((values["src"] or "", "alt" in values))
        if tag == "title":
            self._in_title = True
        if tag == "h1":
            self.h1_count += 1
        if tag == "main" and values.get("id") == "main":
            self.has_main = True
        if tag == "nav" and values.get("aria-label") == "Primary":
            self.has_primary_nav = True
        if tag == "meta" and values.get("name"):
            name = values.get("name") or ""
            self.meta_names[name] = values.get("content") or ""
            if name == "description":
                self.description = values.get("content") or ""
        if tag == "meta" and values.get("property"):
            self.meta_properties[values.get("property") or ""] = values.get("content") or ""
        if tag == "link" and "canonical" in (values.get("rel") or "").split():
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
    if parsed.path.startswith("/"):
        target = (root / parsed.path.lstrip("/")).resolve()
    else:
        target = (page.parent / parsed.path).resolve()
    if parsed.path.endswith("/") or target.is_dir():
        target = target / "index.html"
    if root not in target.parents and target != root:
        raise ValueError(f"path escapes site root: {reference}")
    return target


def schema_types(document: object) -> set[str]:
    if isinstance(document, list):
        return {item.get("@type") for item in document if isinstance(item, dict) and isinstance(item.get("@type"), str)}
    if not isinstance(document, dict):
        return set()
    graph = document.get("@graph")
    if isinstance(graph, list):
        return {item.get("@type") for item in graph if isinstance(item, dict) and isinstance(item.get("@type"), str)}
    value = document.get("@type")
    return {value} if isinstance(value, str) else set()


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    pages = sorted(root.rglob("*.html"))
    errors: list[str] = []
    if len(pages) != 9:
        errors.append(f"expected 9 pages including 404.html, found {len(pages)}")

    parsed_pages: dict[str, PageParser] = {}

    for page in pages:
        parser = PageParser()
        try:
            parser.feed(page.read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"{page.relative_to(root)}: parse error: {exc}")
            continue
        label = str(page.relative_to(root))
        parsed_pages[label] = parser
        if not parser.title.strip(): errors.append(f"{label}: missing title")
        if not (50 <= len(parser.description) <= 165): errors.append(f"{label}: description length {len(parser.description)}")
        if parser.h1_count != 1: errors.append(f"{label}: expected one h1, found {parser.h1_count}")
        if parser.html_lang != "en-US": errors.append(f"{label}: html lang must be en-US")
        if not parser.has_main: errors.append(f"{label}: missing main#main")
        if not parser.has_primary_nav: errors.append(f"{label}: missing labeled primary navigation")
        if not parser.has_skip_link: errors.append(f"{label}: missing skip link")
        if "viewport" not in parser.meta_names: errors.append(f"{label}: missing viewport")
        if label == "404.html":
            if "noindex" not in parser.meta_names.get("robots", ""): errors.append("404.html: must be noindex")
            if parser.canonical: errors.append("404.html: must not declare a canonical")
        else:
            if not parser.canonical.startswith(f"{CANONICAL_ORIGIN}/"): errors.append(f"{label}: candidate canonical missing")
            expected_social = {
                "og:title", "og:description", "og:type", "og:url", "og:image", "og:site_name"
            }
            missing_social = sorted(expected_social - parser.meta_properties.keys())
            if missing_social: errors.append(f"{label}: missing Open Graph metadata {missing_social}")
            expected_twitter = {"twitter:card", "twitter:title", "twitter:description", "twitter:image"}
            missing_twitter = sorted(expected_twitter - parser.meta_names.keys())
            if missing_twitter: errors.append(f"{label}: missing Twitter metadata {missing_twitter}")
            if parser.meta_properties.get("og:url") != parser.canonical: errors.append(f"{label}: og:url must match canonical")
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

    homepage_types = set().union(*(schema_types(doc) for doc in parsed_pages.get("index.html", PageParser()).json_documents))
    if not {"SoftwareApplication", "FAQPage", "Organization", "WebSite"}.issubset(homepage_types):
        errors.append("index.html: missing SoftwareApplication, FAQPage, Organization, or WebSite JSON-LD")

    for label, required in GUIDE_SCHEMA.items():
        types = set().union(*(schema_types(doc) for doc in parsed_pages.get(label, PageParser()).json_documents))
        missing = sorted(required - types)
        if missing: errors.append(f"{label}: missing schema types {missing}")

    indexable = {parser.canonical for label, parser in parsed_pages.items() if label != "404.html" and parser.canonical}
    if len(indexable) != 8:
        errors.append(f"expected 8 unique canonical URLs, found {len(indexable)}")

    sitemap_path = root / "sitemap.xml"
    robots_path = root / "robots.txt"
    if not robots_path.exists() or not sitemap_path.exists():
        errors.append("robots.txt or sitemap.xml missing")
    else:
        try:
            sitemap_root = ElementTree.fromstring(sitemap_path.read_text(encoding="utf-8"))
            sitemap_urls = {
                element.text.strip()
                for element in sitemap_root.findall("{http://www.sitemaps.org/schemas/sitemap/0.9}url/{http://www.sitemaps.org/schemas/sitemap/0.9}loc")
                if element.text
            }
            if sitemap_urls != indexable:
                errors.append(f"sitemap/canonical mismatch: sitemap={sorted(sitemap_urls)} canonicals={sorted(indexable)}")
        except Exception as exc:
            errors.append(f"sitemap.xml: parse error: {exc}")
        if f"Sitemap: {CANONICAL_ORIGIN}/sitemap.xml" not in robots_path.read_text(encoding="utf-8"):
            errors.append("robots.txt: canonical sitemap declaration missing")

    llms_path = root / "llms.txt"
    if not llms_path.exists():
        errors.append("llms.txt missing")
    else:
        llms = llms_path.read_text(encoding="utf-8")
        for url in sorted(indexable):
            if url not in llms: errors.append(f"llms.txt: missing indexable URL {url}")

    redirects_path = root / "_redirects"
    if not redirects_path.exists():
        errors.append("_redirects missing")
    else:
        redirects = redirects_path.read_text(encoding="utf-8")
        for route in ["/index.html / 301", "/privacy/index.html /privacy/ 301", "/terms/index.html /terms/ 301"]:
            if route not in redirects: errors.append(f"_redirects: missing {route}")

    manifest_path = root.parent / "Docs" / "SEARCH-ENGINE.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if manifest.get("schema") != "gds.search-site.v1": errors.append("SEARCH-ENGINE.json: schema mismatch")
        if manifest.get("siteId") != "parknudge-app": errors.append("SEARCH-ENGINE.json: siteId mismatch")
        if manifest.get("canonical", {}).get("origin") != CANONICAL_ORIGIN: errors.append("SEARCH-ENGINE.json: origin mismatch")
        endpoints = manifest.get("endpoints", {})
        if endpoints.get("sitemap") != f"{CANONICAL_ORIGIN}/sitemap.xml": errors.append("SEARCH-ENGINE.json: sitemap mismatch")
        key_url = endpoints.get("indexNowKey", "")
        key_name = Path(urlsplit(key_url).path).name
        key_path = root / key_name
        if not key_name.endswith(".txt") or not key_path.exists(): errors.append("SEARCH-ENGINE.json: IndexNow key file missing")
        elif key_path.read_text(encoding="utf-8").strip() != key_name.removesuffix(".txt"):
            errors.append("IndexNow key file content must match its filename")
    except Exception as exc:
        errors.append(f"SEARCH-ENGINE.json: parse error: {exc}")

    if errors:
        print("Site checks failed:")
        for error in errors: print(f"- {error}")
        return 1
    print(
        "Site checks passed: "
        f"{len(pages)} HTML pages, canonical/sitemap parity, social metadata, JSON-LD, "
        "Cloudflare assets, crawler files, IndexNow key, and search-engine manifest verified."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
