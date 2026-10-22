#!/usr/bin/env python3
"""Shared Zotero Web API client, local index, and download queue.

Example script from claude-code-guide
(https://github.com/alopezespino/claude-code-guide). Edit it to fit your library.

Usage:
    python zotero_api.py sync-index [--full] [--dry-run]
    python zotero_api.py search <text>
    python zotero_api.py stats

Credentials come from the macOS Keychain (services `zotero_api_key` and
`zotero_user_id`). The environment variables ZOTERO_API_KEY and ZOTERO_USER_ID
are read only as a fallback, with a warning.

Paths come from `zotero-config.json` in the current folder (all keys optional),
then from command-line options:

    {
      "index_path": "notes/zotero-index.json",
      "queue_path": "notes/zotero-downloads.md",
      "proxy_prefix": "",
      "email": ""
    }

`proxy_prefix` is your library's proxy login prefix, if it has one; queue links
become `<proxy_prefix>https://doi.org/<DOI>`. `email` is sent to CrossRef and
OpenAlex as a contact and is required by Unpaywall; leave it empty to skip
Unpaywall.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import date, datetime, timezone
from pathlib import Path

import requests
from pyzotero import zotero

API_BASE = "https://api.zotero.org"
INDEX_SCHEMA_VERSION = 1
WORKING_PAPER_TYPES = ("report", "preprint", "manuscript")
SKIP_TYPES = ("attachment", "note", "annotation")

DEFAULT_CONFIG = {
    "index_path": "notes/zotero-index.json",
    "queue_path": "notes/zotero-downloads.md",
    "proxy_prefix": "",
    "email": "",
}


class ZoteroUploadError(RuntimeError):
    """A PDF upload did not produce a verified attachment."""


# ---------------------------------------------------------------- config

def load_config(config_path: str | None = None, overrides: dict | None = None) -> dict:
    """Defaults, then zotero-config.json (or --config), then CLI overrides."""
    cfg = dict(DEFAULT_CONFIG)
    path = Path(config_path) if config_path else Path("zotero-config.json")
    if path.exists():
        with open(path) as f:
            cfg.update({k: v for k, v in json.load(f).items() if k in DEFAULT_CONFIG})
    elif config_path:
        sys.exit(f"Error: config file {path} not found")
    for k, v in (overrides or {}).items():
        if v is not None:
            cfg[k] = v
    cfg["index_path"] = Path(cfg["index_path"]).expanduser()
    cfg["queue_path"] = Path(cfg["queue_path"]).expanduser()
    return cfg


def add_common_args(parser: argparse.ArgumentParser) -> None:
    """Options shared by every script in this folder."""
    parser.add_argument("--config", help="Config file (default: ./zotero-config.json)")
    parser.add_argument("--index", dest="index_path", help="Index file path")
    parser.add_argument("--queue", dest="queue_path", help="Download queue path")
    parser.add_argument("--group", help="Group library name or numeric id "
                        "(default: your personal library)")


def config_from_args(args) -> dict:
    return load_config(args.config, {
        "index_path": getattr(args, "index_path", None),
        "queue_path": getattr(args, "queue_path", None),
    })


def request_headers(cfg: dict) -> dict:
    agent = "claude-code-guide-zotero-example/1.0"
    if cfg.get("email"):
        agent += f" (mailto:{cfg['email']})"
    return {"User-Agent": agent}


def confirm(prompt: str, assume_yes: bool) -> bool:
    """Approval step. Non-interactive shells must pass --yes explicitly."""
    if assume_yes:
        return True
    if not sys.stdin.isatty():
        print(f"{prompt} Not a terminal: re-run with --yes after reviewing "
              "the dry run.")
        return False
    return input(f"{prompt} [y/N] ").strip().lower() in ("y", "yes")


# ---------------------------------------------------------------- secrets

def get_secret(service: str, env_var: str) -> str:
    """Read a secret from the macOS Keychain; env var only as a fallback."""
    try:
        out = subprocess.run(
            ["security", "find-generic-password", "-s", service, "-w"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        if out:
            return out
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    val = os.environ.get(env_var, "").strip()
    if val:
        print(f"Warning: {service} not found in the Keychain; using ${env_var}. "
              "Environment variables leak into logs and child processes; store "
              "it with `security add-generic-password -a \"$USER\" -s "
              f"{service} -w`.", file=sys.stderr)
        return val
    sys.exit(f"Error: no Keychain entry `{service}` and no ${env_var}. "
             "See README.md, section Setup.")


# ---------------------------------------------------------------- helpers

def normalize_doi(doi: str | None) -> str | None:
    if not doi:
        return None
    doi = doi.strip().lower()
    doi = re.sub(r"^(https?://(dx\.)?doi\.org/|doi:\s*)", "", doi)
    return doi or None


def normalize_title(title: str) -> str:
    title = title.lower()
    title = re.sub(r"[{}\\\"]", "", title)
    title = re.sub(r"[^a-z0-9\s]", " ", title)
    return re.sub(r"\s+", " ", title).strip()


def token_similarity(a: str, b: str) -> float:
    ta, tb = set(a.split()), set(b.split())
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / len(ta | tb)


def creators_hash(creators: list[dict]) -> str:
    names = [c.get("lastName", c.get("name", "")).strip().lower() for c in creators]
    return "-".join(sorted(n for n in names if n))


def creators_overlap(hash_a: str, hash_b: str) -> bool:
    a, b = set(hash_a.split("-")), set(hash_b.split("-"))
    if not a or not b:
        return True
    return len(a & b) >= min(len(a), len(b)) * 0.5


def citation_key_from_extra(extra: str) -> str | None:
    for line in extra.splitlines():
        m = re.match(r"(?:Citation Key|bibtex|citation-key)\s*:\s*(.+)", line, re.I)
        if m:
            return m.group(1).strip()
    return None


def year_of(date_str: str) -> str:
    m = re.search(r"\b(\d{4})\b", date_str or "")
    return m.group(1) if m else ""


# ---------------------------------------------------------------- client

class ZoteroClient:
    def __init__(self, cfg: dict, group: str | None = None):
        self.cfg = cfg
        self.api_key = get_secret("zotero_api_key", "ZOTERO_API_KEY")
        self.user_id = get_secret("zotero_user_id", "ZOTERO_USER_ID")
        self.group_id = None
        if group:
            self.group_id = self._resolve_group(group)
            self.zot = zotero.Zotero(self.group_id, "group", self.api_key)
        else:
            self.zot = zotero.Zotero(self.user_id, "user", self.api_key)
        self.index = self._load_index()

    # -- library selection

    def _resolve_group(self, group: str) -> str:
        if group.isdigit():
            return group
        me = zotero.Zotero(self.user_id, "user", self.api_key)
        for g in me.groups():
            if g["data"]["name"].lower() == group.lower():
                return str(g["data"]["id"])
        sys.exit(f"Error: no group named '{group}' in this account")

    @property
    def library_path(self) -> str:
        if self.group_id:
            return f"{API_BASE}/groups/{self.group_id}"
        return f"{API_BASE}/users/{self.user_id}"

    # -- index

    @property
    def index_path(self) -> Path:
        path = self.cfg["index_path"]
        if self.group_id:
            return path.with_name(f"{path.stem}-group-{self.group_id}{path.suffix}")
        return path

    def _empty_index(self) -> dict:
        return {"schema_version": INDEX_SCHEMA_VERSION, "library_version": 0,
                "last_synced": None, "items": {}, "by_citation_key": {},
                "by_doi": {}}

    def _load_index(self) -> dict:
        if self.index_path.exists():
            with open(self.index_path) as f:
                idx = json.load(f)
            if idx.get("schema_version") == INDEX_SCHEMA_VERSION:
                return idx
        return self._empty_index()

    def save_index(self) -> None:
        path = self.index_path
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_name(path.name + ".tmp")
        with open(tmp, "w") as f:
            json.dump(self.index, f, indent=2, ensure_ascii=False)
        os.replace(tmp, path)

    def sync_index(self, full: bool = False, dry_run: bool = False) -> int:
        """Fetch top-level items changed since the indexed library version.

        With dry_run, the index is updated in memory only and not saved.
        """
        if full:
            self.index = self._empty_index()
        since = self.index["library_version"]
        count, start, limit = 0, 0, 100
        while True:
            items = self.zot.top(since=since, limit=limit, start=start,
                                 sort="dateModified", direction="asc")
            if not items:
                break
            for item in items:
                if item["data"].get("itemType") in SKIP_TYPES:
                    continue
                self.index_item(item)
                count += 1
            if len(items) < limit:
                break
            start += limit
        # Deletions since the last sync (incremental only).
        if since and not full:
            try:
                deleted = self.zot.deleted(since=since).get("items", [])
            except Exception:
                deleted = []
            for key in deleted:
                self._drop_from_index(key)
        self.index["library_version"] = int(self.zot.last_modified_version())
        self.index["last_synced"] = datetime.now(timezone.utc).isoformat()
        if not dry_run:
            self.save_index()
        return count

    def _drop_from_index(self, key: str) -> None:
        old = self.index["items"].pop(key, None)
        if not old:
            return
        if self.index["by_citation_key"].get(old.get("citation_key")) == key:
            del self.index["by_citation_key"][old["citation_key"]]
        if self.index["by_doi"].get(old.get("doi")) == key:
            del self.index["by_doi"][old["doi"]]

    def index_item(self, item: dict) -> None:
        data = item.get("data", item)
        if data.get("itemType", "") in SKIP_TYPES:
            return
        key = data["key"]
        ck = data.get("citationKey", "") or citation_key_from_extra(data.get("extra", "")) or ""
        doi = normalize_doi(data.get("DOI", "")) or ""
        self._drop_from_index(key)
        self.index["items"][key] = {
            "key": key,
            "version": data.get("version", 0),
            "item_type": data.get("itemType", ""),
            "citation_key": ck,
            "doi": doi,
            "title": data.get("title", ""),
            "year": year_of(data.get("date", "")),
            "creators_hash": creators_hash(data.get("creators", [])),
        }
        if ck:
            self.index["by_citation_key"][ck] = key
        if doi:
            self.index["by_doi"][doi] = key

    # -- lookup

    def find_by_citation_key(self, citekey: str) -> dict | None:
        key = self.index["by_citation_key"].get(citekey)
        return self.index["items"].get(key) if key else None

    def find_by_doi(self, doi: str) -> dict | None:
        norm = normalize_doi(doi)
        key = self.index["by_doi"].get(norm) if norm else None
        return self.index["items"].get(key) if key else None

    def find_by_fuzzy(self, title: str, chash: str, year: str,
                      threshold: float = 0.85) -> dict | None:
        target = normalize_title(title)
        if not target:
            return None
        best, best_score = None, 0.0
        for entry in self.index["items"].values():
            if year and entry.get("year") and entry["year"] != year:
                continue
            if chash and entry.get("creators_hash") and \
                    not creators_overlap(chash, entry["creators_hash"]):
                continue
            score = token_similarity(target, normalize_title(entry.get("title", "")))
            if score > best_score:
                best, best_score = entry, score
        return best if best_score >= threshold else None

    def working_papers(self, tag: str | None = None) -> list[dict]:
        found = [e for e in self.index["items"].values()
                 if e.get("item_type") in WORKING_PAPER_TYPES]
        if tag:
            tagged = {i["data"]["key"] for i in self.zot.everything(self.zot.top(tag=tag))}
            found = [e for e in found if e["key"] in tagged]
        return found

    # -- reads and writes

    def get_item(self, key: str) -> dict:
        return self.zot.item(key)

    def update_fields(self, key: str, fields: dict) -> dict:
        """Re-read the item, set fields, write, re-read, re-index.

        update_item sends the item's current version, so a change made
        elsewhere since the read makes the API refuse the write (HTTP 412).
        """
        data = self.zot.item(key)["data"]
        data.update(fields)
        self.zot.update_item(data)
        fresh = self.zot.item(key)
        self.index_item(fresh)
        return fresh

    def pdf_attachments(self, parent_key: str) -> list[dict]:
        return [c for c in self.zot.children(parent_key, itemType="attachment")
                if c["data"].get("contentType", "") == "application/pdf"]

    def rename_attachment(self, att_key: str, new_title: str) -> None:
        att = self.zot.item(att_key)
        att["data"]["title"] = new_title
        self.zot.update_item(att["data"])

    def upload_pdf(self, parent_key: str, filepath: Path, filename: str) -> str:
        """Attach a PDF with the Web API's file upload, then verify it.

        Steps: create an imported_file attachment item; ask for upload
        authorization (a reply {"exists": 1} means the server already holds
        these bytes); upload prefix + bytes + suffix; register the uploadKey;
        read the attachment back and require the stored md5 and parentItem to
        match. pyzotero's attachment_simple is not used because it can report
        a failure without raising and leave no attachment. Returns the new
        attachment key; raises ZoteroUploadError on any failure.
        """
        filepath = Path(filepath)
        where = f"upload of {filepath.name} to item {parent_key}"
        content = filepath.read_bytes()
        md5 = hashlib.md5(content).hexdigest()
        mtime = int(filepath.stat().st_mtime * 1000)
        lib = self.library_path
        headers = {"Zotero-API-Key": self.api_key, "Zotero-API-Version": "3"}
        form = {**headers, "If-None-Match": "*",
                "Content-Type": "application/x-www-form-urlencoded"}

        def expect(resp, status, step):
            if resp.status_code != status:
                raise ZoteroUploadError(f"{where}: {step} returned HTTP "
                                        f"{resp.status_code}: {resp.text[:200]}")

        try:
            item = {"itemType": "attachment", "linkMode": "imported_file",
                    "parentItem": parent_key, "title": filename,
                    "contentType": "application/pdf", "filename": filename,
                    "tags": [], "relations": {}}
            r = requests.post(f"{lib}/items", json=[item], headers=headers, timeout=60)
            expect(r, 200, "create attachment item")
            body = r.json()
            att_key = (body.get("success") or {}).get("0")
            if not att_key:
                raise ZoteroUploadError(f"{where}: item not created: {body.get('failed')}")
            where += f" (attachment {att_key})"

            r = requests.post(f"{lib}/items/{att_key}/file", headers=form, timeout=60,
                              data={"md5": md5, "filename": filename,
                                    "filesize": len(content), "mtime": mtime})
            expect(r, 200, "upload authorization")
            auth = r.json()
            if not auth.get("exists"):
                r = requests.post(auth["url"], timeout=300,
                                  headers={"Content-Type": auth["contentType"]},
                                  data=auth["prefix"].encode() + content
                                  + auth["suffix"].encode())
                expect(r, 201, "storage upload")
                r = requests.post(f"{lib}/items/{att_key}/file", headers=form,
                                  data={"upload": auth["uploadKey"]}, timeout=60)
                expect(r, 204, "register upload")

            r = requests.get(f"{lib}/items/{att_key}", headers=headers, timeout=60)
            expect(r, 200, "read-back")
            stored = r.json().get("data", {})
        except requests.RequestException as e:
            raise ZoteroUploadError(f"{where}: {type(e).__name__}: {e}") from e
        except (KeyError, ValueError) as e:
            raise ZoteroUploadError(f"{where}: unexpected response ({e!r})") from e

        if stored.get("md5") != md5:
            raise ZoteroUploadError(f"{where}: stored md5 {stored.get('md5')!r} "
                                    f"differs from local md5 {md5}")
        if stored.get("parentItem") != parent_key:
            raise ZoteroUploadError(f"{where}: parentItem is {stored.get('parentItem')!r}")
        return att_key


# ---------------------------------------------------------------- queue

QUEUE_HEADER = "| Citation key | DOI | Title | Link | Date queued |"
QUEUE_RULE = "|---|---|---|---|---|"


def queue_link(doi: str, cfg: dict) -> str:
    return f"{cfg.get('proxy_prefix', '')}https://doi.org/{doi}"


def new_queue_text() -> str:
    return (f"# Zotero manual downloads\n\n"
            f"Published papers whose PDF is not open access. Download each one "
            f"(through your library if it has access), attach it in Zotero, "
            f"then move its row to Completed.\n\n"
            f"## Pending\n\n{QUEUE_HEADER}\n{QUEUE_RULE}\n\n"
            f"## Completed\n\n{QUEUE_HEADER}\n{QUEUE_RULE}\n")


def queue_add(cfg: dict, citation_key: str, doi: str, title: str,
              dry_run: bool = False) -> bool:
    """Add a Pending row (one per DOI). Returns True if a row was (or would be) added."""
    path = cfg["queue_path"]
    text = path.read_text() if path.exists() else new_queue_text()
    if f"| {doi} |" in text:
        return False
    if dry_run:
        return True
    title = title.replace("|", "/")
    title = title[:80] + ("..." if len(title) > 80 else "")
    row = (f"| {citation_key} | {doi} | {title} | "
           f"[link]({queue_link(doi, cfg)}) | {date.today().isoformat()} |")
    # Insert right after the last table line under "## Pending", so the row
    # stays inside the table (a blank line before it would end the table).
    lines = text.split("\n")
    insert_at, in_pending = None, False
    for i, line in enumerate(lines):
        if line.startswith("## "):
            if in_pending:
                break
            in_pending = line.startswith("## Pending")
        elif in_pending and line.startswith("|"):
            insert_at = i + 1
    if insert_at is None:
        sys.exit(f"Error: no Pending table found in {path}; fix the file by hand.")
    lines.insert(insert_at, row)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines))
    return True


def queue_pending_count(cfg: dict) -> int:
    path = cfg["queue_path"]
    if not path.exists():
        return 0
    pending = path.read_text().split("## Pending", 1)[-1].split("## Completed", 1)[0]
    return sum(1 for line in pending.splitlines()
               if line.startswith("|") and line not in (QUEUE_HEADER, QUEUE_RULE))


# ---------------------------------------------------------------- commands

def cmd_sync_index(args, cfg):
    client = ZoteroClient(cfg, args.group)
    count = client.sync_index(full=args.full, dry_run=args.dry_run)
    print(f"Fetched {count} changed items; index holds {len(client.index['items'])}.")
    print(f"Library version: {client.index['library_version']}")
    if args.dry_run:
        print(f"Dry run: {client.index_path} not written.")
    else:
        print(f"Index: {client.index_path.resolve()}")


def cmd_search(args, cfg):
    client = ZoteroClient(cfg, args.group)
    q = args.query.lower()
    hits = [e for e in client.index["items"].values()
            if q in e.get("citation_key", "").lower()
            or q in e.get("title", "").lower() or q in e.get("doi", "").lower()]
    if not hits:
        print("No matches in the index (run sync-index first if it is old).")
    for e in hits[:20]:
        print(f"  {e.get('citation_key') or '-':30s} {e['key']}  "
              f"{e.get('title', '')[:60]}  {e.get('doi', '')}")


def cmd_stats(args, cfg):
    client = ZoteroClient(cfg, args.group)
    idx = client.index
    by_type: dict[str, int] = {}
    for e in idx["items"].values():
        by_type[e.get("item_type", "?")] = by_type.get(e.get("item_type", "?"), 0) + 1
    print(f"Items: {len(idx['items'])}  version: {idx['library_version']}  "
          f"last synced: {idx.get('last_synced') or 'never'}")
    print(f"Citation keys: {len(idx['by_citation_key'])}  DOIs: {len(idx['by_doi'])}")
    for t, c in sorted(by_type.items(), key=lambda x: -x[1]):
        print(f"  {t:25s} {c}")


def main():
    parser = argparse.ArgumentParser(description="Zotero index utility")
    add_common_args(parser)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("sync-index", help="Update the local index from Zotero")
    p.add_argument("--full", action="store_true", help="Rebuild from scratch")
    p.add_argument("--dry-run", action="store_true", help="Fetch but do not save")
    p.set_defaults(func=cmd_sync_index)
    p = sub.add_parser("search", help="Search the index by key, title or DOI")
    p.add_argument("query")
    p.set_defaults(func=cmd_search)
    p = sub.add_parser("stats", help="Index statistics")
    p.set_defaults(func=cmd_stats)
    args = parser.parse_args()
    args.func(args, config_from_args(args))


if __name__ == "__main__":
    main()
