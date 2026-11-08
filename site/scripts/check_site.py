#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit
from xml.etree import ElementTree


# ParkNudge has no domain of its own. Its public pages live under the publisher
# site, built from lightcloud00/gusdigitalsolutions (src/pages/parknudge/); this
# folder is a source copy whose canonicals must point at those publisher URLs.
PUBLISHER_HOST = "gusdigitalsolutions.com"
PUBLISHER_ORIGIN = f"https://{PUBLISHER_HOST}"
CANONICAL_BASE_PATH = "/parknudge/"
CANONICAL_BASE = f"{PUBLISHER_ORIGIN}{CANONICAL_BASE_PATH}"
PUBLISHER_SITEMAP = f"{PUBLISHER_ORIGIN}/sitemap-index.xml"
# The only hosts a published file may name in an absolute URL.
ALLOWED_URL_HOSTS = {PUBLISHER_HOST, "github.com", "apps.apple.com", "schema.org", "www.sitemaps.org"}
ABSOLUTE_URL = re.compile(r"https?://[^\s\"'<>()\[\]{}]+", re.IGNORECASE)
# A domain-shaped ParkNudge name (parknudge.app, www.parknudge.com), with or without
# a scheme. A reverse-DNS identifier such as com.example.parknudge.pro is not matched.
PARKNUDGE_DOMAIN = re.compile(r"(?<![\w.-])(?:www\.)?parknudge\.[a-z]{2,63}\b", re.IGNORECASE)
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


def schema_nodes(document: object) -> list[dict]:
    if isinstance(document, dict) and isinstance(document.get("@graph"), list):
        document = document["@graph"]
    items = document if isinstance(document, list) else [document]
    return [item for item in items if isinstance(item, dict)]


def schema_types(document: object) -> set[str]:
    return {node["@type"] for node in schema_nodes(document) if isinstance(node.get("@type"), str)}


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
            page_dir = page.parent.relative_to(root).as_posix()
            own_url = CANONICAL_BASE if page_dir == "." else f"{CANONICAL_BASE}{page_dir}/"
            if parser.canonical != own_url: errors.append(f"{label}: canonical must be its own page {own_url}, found {parser.canonical!r}")
            for node in (node for document in parser.json_documents for node in schema_nodes(document)):
                if node.get("@type") == "Article":
                    entity = node.get("mainEntityOfPage")
                    entity = entity.get("@id") if isinstance(entity, dict) else entity
                    if entity != parser.canonical: errors.append(f"{label}: Article mainEntityOfPage must equal the canonical")
                if node.get("@type") == "BreadcrumbList":
                    crumbs = node.get("itemListElement")
                    last = crumbs[-1].get("item") if isinstance(crumbs, list) and crumbs and isinstance(crumbs[-1], dict) else None
                    if last != parser.canonical: errors.append(f"{label}: last breadcrumb item must equal the canonical")
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
        if f"Sitemap: {PUBLISHER_SITEMAP}" not in robots_path.read_text(encoding="utf-8"):
            errors.append("robots.txt: publisher sitemap declaration missing")

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
        canonical = manifest.get("canonical", {})
        if canonical.get("origin") != PUBLISHER_ORIGIN: errors.append("SEARCH-ENGINE.json: origin mismatch")
        if canonical.get("basePath") != CANONICAL_BASE_PATH: errors.append("SEARCH-ENGINE.json: basePath mismatch")
        endpoints = manifest.get("endpoints", {})
        if endpoints.get("sitemap") != PUBLISHER_SITEMAP: errors.append("SEARCH-ENGINE.json: sitemap mismatch")
        for name in ("robots", "llms"):
            if endpoints.get(name) != f"{PUBLISHER_ORIGIN}/{name}.txt": errors.append(f"SEARCH-ENGINE.json: {name} mismatch")
        # The publisher host owns the IndexNow key file at its root (it lives in the
        # gusdigitalsolutions repository, so its content cannot be read from here).
        key = urlsplit(endpoints.get("indexNowKey", ""))
        key_stem = key.path.removeprefix("/").removesuffix(".txt")
        if (
            f"{key.scheme}://{key.netloc}" != PUBLISHER_ORIGIN
            or not key.path.endswith(".txt")
            or "/" in key_stem
            or not 8 <= len(key_stem) <= 128
            or any(c not in "0123456789abcdefABCDEF-" for c in key_stem)
        ):
            errors.append("SEARCH-ENGINE.json: indexNowKey must be a key file at the publisher root")
    except Exception as exc:
        errors.append(f"SEARCH-ENGINE.json: parse error: {exc}")

    # ParkNudge has no domain of its own. A published file (everything in site/ except
    # scripts/, plus SEARCH-ENGINE.json) may name only the allowed hosts, every
    # gusdigitalsolutions.com/parknudge/ URL must match a page or asset in site/, and
    # no parknudge.<tld> domain may appear, even without a scheme.
    for path in sorted([*root.rglob("*"), manifest_path]):
        if not path.is_file() or "scripts" in path.relative_to(root.parent).parts or path.suffix not in {".html", ".txt", ".xml", ".json", ".css", ""}:
            continue
        name = path.relative_to(root.parent)
        text = path.read_text(encoding="utf-8", errors="replace")
        for domain in sorted({match.group(0).lower() for match in PARKNUDGE_DOMAIN.finditer(text)}):
            errors.append(f"{name}: names {domain}; ParkNudge has no domain of its own, use {CANONICAL_BASE}")
        for url in sorted({match.rstrip(".,;:!?") for match in ABSOLUTE_URL.findall(text)}):
            parts = urlsplit(url)
            host = (parts.hostname or "").lower()
            if host not in ALLOWED_URL_HOSTS:
                errors.append(f"{name}: links to {url}; allowed hosts are {', '.join(sorted(ALLOWED_URL_HOSTS))}")
            elif host == PUBLISHER_HOST and parts.path.startswith(CANONICAL_BASE_PATH):
                try:
                    target = local_target(root / "index.html", "/" + parts.path.removeprefix(CANONICAL_BASE_PATH), root)
                except ValueError as exc:
                    errors.append(f"{name}: {exc}")
                    continue
                if target is None or not target.is_file():
                    errors.append(f"{name}: {url} has no matching page or asset in site/")

    if errors:
        print("Site checks failed:")
        for error in errors: print(f"- {error}")
        return 1
    print(
        "Site checks passed: "
        f"{len(pages)} HTML pages, own-page canonicals, canonical/sitemap parity, social metadata, JSON-LD, "
        "Cloudflare assets, crawler files, link hosts, and publisher-hosted search-engine manifest verified."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
