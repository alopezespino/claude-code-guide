#!/usr/bin/env python3
"""Find newer or published versions of working papers in a Zotero library.

Example script from claude-code-guide
(https://github.com/alopezespino/claude-code-guide). Edit it to fit your library.

Usage:
    python zotero_update_paper.py --check-all --dry-run
    python zotero_update_paper.py --citation-key doe2020trade [--yes]
    python zotero_update_paper.py --tag to-check --dry-run

Working papers are items of type report, preprint or manuscript. For each one
the script asks CrossRef for a newer working-paper version (by DOI relations)
and for a published journal version (by DOI relations, then by title and first
author), and checks open access through OpenAlex and Unpaywall. Policy:

  newer working-paper version       download and attach the PDF
  published, open publishedVersion  update metadata, download and attach
  published, accepted manuscript    update metadata, queue; never attached
  published, paywalled              update metadata, queue; never an open
                                    preprint as a substitute

Existing PDFs are never overwritten or deleted: after the new PDF is uploaded
and verified, each older PDF attachment's title gets a `_wp<year>` suffix.
With --dry-run the script prints the plan and writes nothing (no Zotero
change, no download, no queue row).
"""

from __future__ import annotations

import argparse
import re
import sys
import tempfile
import time
from datetime import date
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
from zotero_api import (WORKING_PAPER_TYPES, ZoteroClient, ZoteroUploadError,
                        add_common_args, config_from_args, confirm, normalize_doi,
                        normalize_title, queue_add, queue_pending_count,
                        request_headers, token_similarity)

CROSSREF_API = "https://api.crossref.org"
OPENALEX_API = "https://api.openalex.org"
UNPAYWALL_API = "https://api.unpaywall.org/v2"

HEADERS: dict = {}
EMAIL = ""


def _get(url: str, params: dict | None = None) -> dict | None:
    try:
        r = requests.get(url, params=params, headers=HEADERS, timeout=20)
        return r.json() if r.status_code == 200 else None
    except (requests.RequestException, ValueError):
        return None


# ---------------------------------------------------------------- CrossRef

def crossref_work(doi: str) -> dict | None:
    msg = (_get(f"{CROSSREF_API}/works/{doi}") or {}).get("message")
    return parse_crossref(msg) if msg else None


def parse_crossref(item: dict) -> dict:
    year = ""
    for f in ("published-print", "published-online", "published", "issued"):
        parts = (item.get(f) or {}).get("date-parts", [[]])
        if parts and parts[0] and parts[0][0]:
            year = str(parts[0][0])
            break
    return {
        "doi": item.get("DOI", ""),
        "title": " ".join(item.get("title", [])),
        "year": year,
        "venue": (item.get("container-title") or [""])[0],
        "type": item.get("type", ""),
        "volume": item.get("volume", ""),
        "issue": item.get("issue", ""),
        "page": item.get("page", ""),
        "relation": item.get("relation", {}),
    }


def related_dois(work: dict, rel_types: tuple) -> list[str]:
    out = []
    for rt in rel_types:
        for rel in work.get("relation", {}).get(rt, []):
            rid = re.sub(r"^https?://(dx\.)?doi\.org/", "", rel.get("id", ""))
            if "/" in rid:
                out.append(rid)
    return out


def is_repository(venue: str) -> bool:
    v = venue.lower()
    return any(s in v for s in ("ssrn", "working paper", "arxiv", "repec"))


def newer_wp_version(work: dict | None) -> dict | None:
    if not work:
        return None
    for doi in related_dois(work, ("is-previous-version-of", "has-new-version",
                                   "is-obsoleted-by")):
        newer = crossref_work(doi)
        if newer and newer["type"] != "journal-article":
            return newer
    return None


def published_version(work: dict | None, title: str, chash: str) -> dict | None:
    if work:
        for doi in related_dois(work, ("is-preprint-of", "is-version-of",
                                       "is-replaced-by")):
            pub = crossref_work(doi)
            if pub and pub["type"] == "journal-article" and not is_repository(pub["venue"]):
                return pub
    target = normalize_title(title)
    if not target:
        return None
    params = {"query.bibliographic": title, "rows": 5, "filter": "type:journal-article"}
    first_author = chash.split("-")[0] if chash else ""
    if first_author:
        params["query.author"] = first_author
    if EMAIL:
        params["mailto"] = EMAIL
    items = ((_get(f"{CROSSREF_API}/works", params) or {}).get("message") or {}).get("items", [])
    for item in items:
        cand = parse_crossref(item)
        if is_repository(cand["venue"]):
            continue
        if token_similarity(target, normalize_title(cand["title"])) >= 0.80:
            return cand
    return None


# ---------------------------------------------------------------- open access

def oa_status(doi: str) -> dict:
    """OpenAlex, then Unpaywall (if an email is configured); prefer publishedVersion."""
    best = {"is_oa": False, "pdf_url": None, "version": None, "source": None}
    params = {"mailto": EMAIL} if EMAIL else None
    data = _get(f"{OPENALEX_API}/works/doi:{doi}", params)
    if data and data.get("open_access", {}).get("is_oa"):
        loc = data.get("best_oa_location") or {}
        best = {"is_oa": True, "pdf_url": loc.get("pdf_url"),
                "version": loc.get("version"), "source": "openalex"}
        if best["version"] == "publishedVersion" and best["pdf_url"]:
            return best
    if EMAIL:
        data = _get(f"{UNPAYWALL_API}/{doi}", {"email": EMAIL})
        if data and data.get("is_oa"):
            loc = data.get("best_oa_location") or {}
            cand = {"is_oa": True, "pdf_url": loc.get("url_for_pdf"),
                    "version": loc.get("version"), "source": "unpaywall"}
            if not best["is_oa"] or (cand["version"] == "publishedVersion"
                                     and best["version"] != "publishedVersion"):
                best = cand
    return best


def download_pdf(url: str, dest: Path) -> bool:
    """Download into dest (inside a temporary folder); keep it only if it is a PDF."""
    try:
        r = requests.get(url, headers=HEADERS, timeout=60, stream=True)
        if r.status_code != 200:
            return False
        with open(dest, "wb") as f:
            for chunk in r.iter_content(chunk_size=65536):
                f.write(chunk)
    except requests.RequestException:
        return False
    with open(dest, "rb") as f:
        return f.read(5) == b"%PDF-"


# ---------------------------------------------------------------- plan

def check_paper(entry: dict) -> dict:
    res = {"key": entry["key"], "citation_key": entry.get("citation_key") or entry["key"],
           "year": entry.get("year", ""), "status": "no update", "action": "skip",
           "source": None, "oa": None}
    doi = entry.get("doi", "")
    work = crossref_work(doi) if doi else None

    newer = newer_wp_version(work)
    if newer:
        res.update(source=newer, status="newer working paper",
                   oa=oa_status(newer["doi"]) if newer.get("doi") else None)
        res["action"] = "attach new version"
        return res

    pub = published_version(work, entry.get("title", ""), entry.get("creators_hash", ""))
    if pub and pub.get("doi") and normalize_doi(pub["doi"]) != normalize_doi(doi):
        oa = oa_status(pub["doi"])
        res.update(source=pub, oa=oa)
        if oa["is_oa"] and oa["version"] == "publishedVersion" and oa["pdf_url"]:
            res.update(status="published, open", action="metadata + attach")
        elif oa["is_oa"] and oa["version"] == "acceptedVersion":
            res.update(status="published, accepted manuscript open",
                       action="metadata + queue")
        else:
            res.update(status="published, paywalled", action="metadata + queue")
    return res


KEEP_ON_TYPE_CHANGE = {"key", "version", "collections", "relations", "tags",
                       "dateAdded", "dateModified"}


def published_fields(client: ZoteroClient, data: dict, pub: dict) -> tuple[dict, list]:
    """Fields to set for a published version, and fields a type change removes.

    A journalArticle cannot hold report-only fields (institution, reportNumber,
    and so on), so they are removed; the dry run lists the non-empty ones.
    """
    fields, removed = {}, []
    if data.get("itemType") in WORKING_PAPER_TYPES:
        valid = set(client.zot.item_template("journalArticle")) | KEEP_ON_TYPE_CHANGE
        removed = [f for f in data if f not in valid]
        fields["itemType"] = "journalArticle"
    for zf, pf in (("DOI", "doi"), ("publicationTitle", "venue"), ("date", "year"),
                   ("volume", "volume"), ("issue", "issue"), ("pages", "page")):
        if pub.get(pf):
            fields[zf] = pub[pf]
    return fields, removed


def apply_published_metadata(client: ZoteroClient, key: str, pub: dict) -> None:
    data = client.get_item(key)["data"]
    fields, removed = published_fields(client, data, pub)
    for f in removed:
        data.pop(f, None)
    data.update(fields)
    client.zot.update_item(data)
    fresh = client.get_item(key)["data"]
    wrong = [f for f, v in fields.items() if fresh.get(f) != v]
    if wrong:
        raise RuntimeError(f"re-read of {key}: fields not updated: {', '.join(wrong)}")
    client.index_item(fresh)


def attach_new_pdf(client: ZoteroClient, res: dict) -> str:
    """Download, upload, verify, then rename older PDFs with _wp<year>."""
    url = (res["oa"] or {}).get("pdf_url")
    if not url:
        return "no PDF URL"
    key, ck = res["key"], res["citation_key"]
    old = client.pdf_attachments(key)
    with tempfile.TemporaryDirectory() as tmp:
        pdf = Path(tmp) / f"{ck}.pdf"
        if not download_pdf(url, pdf):
            return "download failed or not a PDF"
        att_key = client.upload_pdf(key, pdf, f"{ck}.pdf")
    # Re-read: the new attachment must be among the item's children now.
    if att_key not in {a["data"]["key"] for a in client.pdf_attachments(key)}:
        raise ZoteroUploadError(f"attachment {att_key} not listed under {key}")
    suffix = f"_wp{res['year']}" if res["year"] else f"_v{date.today().isoformat()}"
    for a in old:
        title = a["data"].get("title", "")
        if suffix not in title:
            stem, ext = (title[:-4], title[-4:]) if title.lower().endswith(".pdf") else (title, "")
            client.rename_attachment(a["data"]["key"], f"{stem}{suffix}{ext}")
    return f"attached {att_key}; {len(old)} older PDF(s) renamed with {suffix}"


def apply_result(client: ZoteroClient, cfg: dict, res: dict) -> str:
    src, ck = res["source"], res["citation_key"]
    notes = []
    if res["action"].startswith("metadata"):
        apply_published_metadata(client, res["key"], src)
        notes.append("metadata updated")
    if res["action"].endswith("queue"):
        added = queue_add(cfg, ck, src["doi"], src["title"])
        notes.append("queued" if added else "already queued")
    elif res["action"].endswith("attach") or res["action"] == "attach new version":
        outcome = attach_new_pdf(client, res)
        notes.append(outcome)
        if outcome.startswith(("no PDF", "download failed")) and src.get("doi") \
                and res["action"] != "attach new version":
            queue_add(cfg, ck, src["doi"], src["title"])
            notes.append("queued")
    return "; ".join(notes)


# ---------------------------------------------------------------- main

def main():
    global HEADERS, EMAIL
    parser = argparse.ArgumentParser(description="Check working papers for newer versions")
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--check-all", action="store_true", help="All working papers")
    scope.add_argument("--citation-key", help="One item by citation key")
    scope.add_argument("--tag", help="Working papers with this tag")
    add_common_args(parser)
    parser.add_argument("--dry-run", action="store_true", help="Print the plan, write nothing")
    parser.add_argument("--yes", action="store_true", help="Apply without the prompt")
    parser.add_argument("--no-sync", action="store_true", help="Skip the index sync")
    args = parser.parse_args()

    cfg = config_from_args(args)
    HEADERS, EMAIL = request_headers(cfg), cfg.get("email", "")
    if not EMAIL:
        print("Note: no email in the config, so Unpaywall is skipped.", file=sys.stderr)
    client = ZoteroClient(cfg, args.group)

    # 1. Read.
    if not args.no_sync:
        n = client.sync_index(dry_run=args.dry_run)
        print(f"Index synced ({n} changed items).")
    if args.citation_key:
        hit = client.find_by_citation_key(args.citation_key)
        if not hit:
            sys.exit(f"Error: {args.citation_key} not in the index")
        papers = [hit]
    else:
        papers = client.working_papers(tag=args.tag)
    if not papers:
        print("No working papers found.")
        return

    print(f"Checking {len(papers)} working paper(s)")
    results = []
    for i, p in enumerate(papers, 1):
        res = check_paper(p)
        print(f"  [{i}/{len(papers)}] {res['citation_key']}: {res['status']}")
        results.append(res)
        time.sleep(0.5)  # be polite to CrossRef and OpenAlex

    todo = [r for r in results if r["action"] != "skip"]
    if not todo:
        print("No updates found.")
        return

    # 2. Dry run: the plan.
    print("\n| Citation key | Status | New DOI | Venue | Action | Fields dropped |")
    print("|---|---|---|---|---|---|")
    for r in todo:
        dropped = ""
        if r["action"].startswith("metadata"):
            data = client.get_item(r["key"])["data"]
            _, removed = published_fields(client, data, r["source"])
            dropped = ", ".join(f for f in removed if data.get(f))
        print(f"| {r['citation_key']} | {r['status']} | {r['source'].get('doi', '')} | "
              f"{r['source'].get('venue', '')[:30]} | {r['action']} | {dropped} |")
    if args.dry_run:
        print(f"\nDry run: {len(todo)} item(s) would change. Nothing written.")
        return

    # 3. Approval.
    if not confirm(f"Apply {len(todo)} change(s)?", args.yes):
        print("Nothing written.")
        return

    # 4. Apply; 5. re-read happens inside each step.
    failures = []
    for r in todo:
        try:
            outcome = apply_result(client, cfg, r)
        except Exception as e:  # report and continue with the next item
            outcome = f"FAILED: {e}"
            failures.append(r["citation_key"])
        print(f"  {r['citation_key']}: {outcome}")
    client.save_index()

    pending = queue_pending_count(cfg)
    print(f"\nDone: {len(todo) - len(failures)} applied, {len(failures)} failed.")
    if pending:
        print(f"{pending} paper(s) pending manual download: {cfg['queue_path'].resolve()}")
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
