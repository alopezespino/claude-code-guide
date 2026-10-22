#!/usr/bin/env python3
"""Update Zotero item metadata from a .bib file.

Example script from claude-code-guide
(https://github.com/alopezespino/claude-code-guide). Edit it to fit your library.

Usage:
    python zotero_update_meta.py refs.bib --dry-run
    python zotero_update_meta.py refs.bib [--fields title,DOI,date] [--yes]

Each .bib entry is matched to a library item by citation key, then DOI, then
normalized title plus authors and year. Matched items are re-read from the API
and compared field by field. The script prints a table (key, field, Zotero
value, .bib value) and writes nothing with --dry-run. Without it, the script
asks for approval (or takes --yes), writes the changes, re-reads each changed
item and reports any field that still differs. Unmatched entries are listed,
never created. Creators are not changed.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import bibtexparser

sys.path.insert(0, str(Path(__file__).resolve().parent))
from zotero_api import (ZoteroClient, add_common_args, config_from_args, confirm,
                        creators_hash, normalize_doi, year_of)

BIB_TO_ZOTERO_FIELD = {
    "title": "title",
    "year": "date",
    "doi": "DOI",
    "journal": "publicationTitle",
    "volume": "volume",
    "number": "issue",
    "pages": "pages",
    "abstract": "abstractNote",
    "issn": "ISSN",
    "url": "url",
    "language": "language",
    "shorttitle": "shortTitle",
    "publisher": "publisher",
}

ACCENTS = {
    "'": dict(zip("aeiouAEIOU", "áéíóúÁÉÍÓÚ")),
    "`": dict(zip("aeiou", "àèìòù")),
    '"': dict(zip("aeiouAEIOU", "äëïöüÄËÏÖÜ")),
    "~": dict(zip("nNao", "ñÑãõ")),
    "^": dict(zip("aeiou", "âêîôû")),
    "c": {"c": "ç", "C": "Ç"},
    "v": dict(zip("cszCSZ", "čšžČŠŽ")),
}


def clean_latex(text: str) -> str:
    """Turn LaTeX accents into Unicode and drop braces and escapes."""
    if not text:
        return text

    def accent(m):
        return ACCENTS.get(m.group(1), {}).get(m.group(2), m.group(2))

    text = re.sub(r"\\i(?![A-Za-z])", "i", text)  # dotless i, as in \'\i
    text = re.sub(r"\{?\\(['`\"~^])\{?([A-Za-z])\}?\}?", accent, text)
    text = re.sub(r"\{?\\([cv])\{([A-Za-z])\}\}?", accent, text)
    text = text.replace("{", "").replace("}", "")
    text = text.replace(r"\&", "&")
    text = re.sub(r"\\([$%#_])", r"\1", text)
    return re.sub(r"\s+", " ", text).strip()


def comparable(text: str) -> str:
    text = clean_latex(str(text)).lower()
    text = re.sub(r"[^a-z0-9\s]", "", text)
    return re.sub(r"\s+", " ", text).strip()


def parse_authors(author_str: str) -> list[dict]:
    authors = []
    for name in clean_latex(author_str).split(" and "):
        name = name.strip()
        if not name:
            continue
        if "," in name:
            last, first = (p.strip() for p in name.split(",", 1))
        elif " " in name:
            first, last = (p.strip() for p in name.rsplit(" ", 1))
        else:
            first, last = "", name
        authors.append({"creatorType": "author", "lastName": last, "firstName": first})
    return authors


def parse_bib(path: Path) -> list[dict]:
    with open(path) as f:
        db = bibtexparser.load(f)
    entries = []
    for e in db.entries:
        fields = {z: clean_latex(e[b]) for b, z in BIB_TO_ZOTERO_FIELD.items() if e.get(b)}
        if e.get("doi"):
            fields["DOI"] = normalize_doi(e["doi"]) or ""
        entries.append({
            "citation_key": e.get("ID", ""),
            "fields": fields,
            "authors": parse_authors(e["author"]) if e.get("author") else [],
        })
    return entries


def match_entry(client: ZoteroClient, entry: dict) -> tuple[dict | None, str]:
    if entry["citation_key"]:
        hit = client.find_by_citation_key(entry["citation_key"])
        if hit:
            return hit, "key"
    doi = entry["fields"].get("DOI")
    if doi:
        hit = client.find_by_doi(doi)
        if hit:
            return hit, "DOI"
    hit = client.find_by_fuzzy(entry["fields"].get("title", ""),
                               creators_hash(entry["authors"]),
                               year_of(entry["fields"].get("date", "")))
    return (hit, "title") if hit else (None, "")


def compute_diff(entry: dict, data: dict, only: set | None) -> dict:
    """Fields where the .bib has a value that differs from Zotero's."""
    diffs = {}
    for field, bib_val in entry["fields"].items():
        if only and field not in only:
            continue
        if field not in data:
            continue  # not a valid field for this item type
        zot_val = data.get(field, "") or ""
        if field == "DOI":
            differs = (normalize_doi(bib_val) or "") != (normalize_doi(zot_val) or "")
        elif field == "date":
            differs = bool(year_of(bib_val)) and year_of(bib_val) != year_of(zot_val)
        else:
            differs = comparable(bib_val) != comparable(zot_val)
        if differs and str(bib_val).strip():
            diffs[field] = (zot_val, bib_val)
    return diffs


def print_table(all_diffs: dict) -> None:
    print("| Citation key | Field | Zotero (now) | .bib (proposed) |")
    print("|---|---|---|---|")
    for ck, diffs in sorted(all_diffs.items()):
        for field, (old, new) in sorted(diffs.items()):
            old_s = (str(old) or "(empty)")[:60].replace("|", "/")
            new_s = (str(new) or "(empty)")[:60].replace("|", "/")
            print(f"| {ck} | {field} | {old_s} | {new_s} |")


def main():
    parser = argparse.ArgumentParser(description="Update Zotero metadata from a .bib file")
    parser.add_argument("bibfile", type=Path)
    add_common_args(parser)
    parser.add_argument("--fields", help="Comma-separated Zotero fields to compare")
    parser.add_argument("--dry-run", action="store_true", help="Show the diff, write nothing")
    parser.add_argument("--yes", action="store_true", help="Apply without the prompt")
    parser.add_argument("--no-sync", action="store_true",
                        help="Skip the index sync before matching")
    args = parser.parse_args()

    if not args.bibfile.exists():
        sys.exit(f"Error: {args.bibfile} not found")
    cfg = config_from_args(args)
    only = set(args.fields.split(",")) if args.fields else None
    client = ZoteroClient(cfg, args.group)

    # 1. Read: refresh the index so matching uses the current library.
    if not args.no_sync:
        n = client.sync_index(dry_run=args.dry_run)
        print(f"Index synced ({n} changed items).")

    entries = parse_bib(args.bibfile)
    print(f"{len(entries)} entries in {args.bibfile}")

    matched, unmatched, all_diffs = {}, [], {}
    for entry in entries:
        ck = entry["citation_key"]
        hit, how = match_entry(client, entry)
        if not hit:
            unmatched.append(ck)
            continue
        matched[ck] = (hit["key"], how)
        data = client.get_item(hit["key"])["data"]
        diffs = compute_diff(entry, data, only)
        if diffs:
            all_diffs[ck] = diffs

    print(f"Matched {len(matched)}, unmatched {len(unmatched)}, "
          f"with differences {len(all_diffs)}")
    fuzzy = [ck for ck, (_, how) in matched.items() if how == "title" and ck in all_diffs]
    if fuzzy:
        print(f"Matched by title only (check these rows): {', '.join(fuzzy)}")
    if unmatched:
        print(f"Unmatched (not created; use an add step): {', '.join(unmatched)}")

    # 2. Dry run.
    if not all_diffs:
        print("No updates needed.")
        return
    print()
    print_table(all_diffs)
    n_fields = sum(len(d) for d in all_diffs.values())
    if args.dry_run:
        print(f"\nDry run: {n_fields} field changes on {len(all_diffs)} items. "
              "Nothing written.")
        return

    # 3. Approval.
    if not confirm(f"Apply {n_fields} field changes to {len(all_diffs)} items?", args.yes):
        print("Nothing written.")
        return

    # 4. Apply, then 5. re-read.
    updated, failed, still_differs = 0, [], []
    for ck, diffs in all_diffs.items():
        key = matched[ck][0]
        try:
            fresh = client.update_fields(key, {f: new for f, (_, new) in diffs.items()})
            updated += 1
            remaining = compute_diff({"fields": {f: n for f, (_, n) in diffs.items()}},
                                     fresh["data"], None)
            if remaining:
                still_differs.append(f"{ck}: {', '.join(remaining)}")
        except Exception as e:
            failed.append(f"{ck}: {e}")
    client.save_index()

    print(f"\nUpdated {updated}, failed {len(failed)}.")
    for line in failed:
        print(f"  FAILED {line}", file=sys.stderr)
    for line in still_differs:
        print(f"  Still differs after re-read: {line}", file=sys.stderr)
    if failed or still_differs:
        sys.exit(1)


if __name__ == "__main__":
    main()
