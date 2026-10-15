---
description: Manage a Zotero library via the Web API (add, update, clean, dedup, PDFs, tags)
argument-hint: <add|meta|papers|clean|dedup|attach|tags> [args] [--group <name>]
---

> Example command from
> [claude-code-guide](https://github.com/alopezespino/claude-code-guide),
> not built into Claude Code. Edit this file to change what the command does.

Run the Zotero task `$ARGUMENTS`. If no subcommand is given, infer it from my request;
ask only if it is ambiguous.

Prerequisites (once):

```bash
python3 -m venv ~/.venvs/zotero
~/.venvs/zotero/bin/pip install pyzotero bibtexparser requests
security add-generic-password -a "$USER" -s zotero_api_key -w
security add-generic-password -a "$USER" -s zotero_user_id -w
```

Each `security` line prompts for the value. Create the key at
https://www.zotero.org/settings/keys with library and write access (and any group you
use); that page also shows your numeric user id. Better BibTeX is optional.

## Access

1. Use the Zotero Web API v3 through `pyzotero` (or curl with the headers
   `Zotero-API-Key` and `Zotero-API-Version: 3`). Run helper scripts with
   `~/.venvs/zotero/bin/python` (or the interpreter CLAUDE.md names), and write them to
   a temporary folder, not into the project.
2. Read the key and the id inside the script at the moment of use:
   `security find-generic-password -s zotero_api_key -w` (same for `zotero_user_id`).
   Never print them, log them, or write them to any file.
3. The personal library is the default:
   `zotero.Zotero(user_id, "user", key)`. For `--group <name>`, match the name
   case-insensitively against `zot.groups()` and use `zotero.Zotero(id, "group", key)`.

## Every subcommand that writes

1. Read before acting. Fetch the items in scope from the API now (for the whole library,
   `zot.everything(zot.top())`). Never act on a saved copy older than
   `zot.last_modified_version()`.
2. Dry run. Compute the full set of changes without writing anything.
3. Show a table (item, action or field, old value, new value) and wait for my approval.
   For merges and deletions, list every item and attachment affected.
4. Apply. Then re-read every changed item and report counts: created, updated,
   downloaded, queued, failed. If anything was queued, give the queue file's full path.

## Subcommands

- `add <file.bib> [collection]`: match each entry to the library by citation key, then
  DOI, then normalized title. Create only the missing ones, from
  `zot.item_template(<type>)` (article: journalArticle, techreport: report,
  unpublished: manuscript, incollection: bookSection). Add them to the collection if
  given (check `zot.collections()` before creating one). Then apply the PDF policy,
  unless I say `--no-download`.
- `meta <file.bib> [--fields a,b]`: match items the same way and show a field-by-field
  diff; with `--fields`, change only those fields. Report unmatched entries; do not
  create them (that is `add`).
- `papers [key | --collection c | --tag t | --all]`: working papers are items of type
  `report` whose type field contains "working paper", `preprint`, or `manuscript`.
  Look for a published version or a newer draft (CrossRef, OpenAlex, by DOI and by
  title plus first author), then apply the PDF policy.
- `clean [keys | --collection c | --tag t | --all] [--no-enrich]`: normalize DOIs to
  the bare `10.xxxx/...` form, strip LaTeX artifacts (braces, accent commands, `\&`)
  from titles and names, and fill missing fields from CrossRef (about 0.5 s per item;
  `--no-enrich` skips this). When matching on CrossRef, prefer journal articles over
  SSRN and working-paper repositories.
- `dedup [scope] [--threshold 0.85]`: candidates share a DOI, or have a fuzzy title plus
  first-author match at or above the threshold. The primary is the published version,
  not the working paper. Plan: move notes and attachments to the primary (change their
  `parentItem`), copy tags and collections, label each PDF by version, and of two
  identical PDFs keep the one with annotations. There is no merge endpoint and an API
  deletion is permanent, so delete a duplicate only after approval, or do the merge in
  Zotero desktop's Duplicate Items view, which moves the merged copies to the Trash.
- `attach <folder>`: match each PDF to an item by a DOI on its first page, then by a
  DOI in its file name or a queue row, then by fuzzy title. Attach exact and queue
  matches; ask about each fuzzy one. Name attachments `Author_etal_Year_ShortTitle.pdf`.
  After the upload is verified, move the local PDF to the Trash (`trash`, never `rm`)
  and move its queue row to Completed.
- `tags <request in plain words>`: parse it into add, remove, list or show. "Working
  papers" means the definition under `papers`. Tag names are case-sensitive; use
  lowercase unless told otherwise. A remove with no items named removes the tag from
  every item that has it: show that count first.

If a `.bib` is needed and not given, use the one named in the project's CLAUDE.md, else
search the project folder (`find . -name "*.bib"`); never search the whole disk.

## PDF policy (for `add` and `papers`)

| Situation | Action |
|---|---|
| A newer working-paper version exists | Download and attach, open or not |
| Published, open publisher version (`publishedVersion`) | Download and attach |
| Published, only the accepted manuscript open (`acceptedVersion`) | Report it; ask first |
| Published, paywalled | Update metadata only; never substitute an open preprint; queue it |
| No DOI | Skip the lookup; create the item without an attachment |

1. Before calling a PDF missing, check the item's attachment children (and the `.bib`
   entry's `file` field). In a folder, count files by the `.pdf` extension only, never
   by a "pdf" substring.
2. Find open copies through OpenAlex (`https://api.openalex.org/works/doi:<DOI>`), then
   Unpaywall (`https://api.unpaywall.org/v2/<DOI>?email=<email>`; ask me for the email once), preferring a
   `publishedVersion` PDF. Keep a download only if the file starts with `%PDF-`.
3. Never overwrite an existing PDF attachment. Keep the old one and rename its title
   with a version suffix: `_wp<year>`, `_published`, `_slides`, `_appendix`.
4. Queue paywalled items in the download queue named in CLAUDE.md, default
   `notes/zotero-downloads.md` (create the file and its folder if missing): a
   Pending and a Completed table with citation key, DOI, title, link and date. The link
   is `https://doi.org/<DOI>`, through your library's proxy, if it has one. One row per
   DOI. Keep table rows contiguous: a blank line after the header breaks the table.

## Uploads: verify, never assume

1. Upload with `zot.attachment_simple([path], parent_key)`. It can return a `failure`
   list instead of raising, and then no attachment exists.
2. Always re-read `zot.children(parent_key, itemType="attachment")` and check that the
   new attachment is there and has an `md5`.
3. If it is not, use the API's three-step file upload: create an `imported_file`
   attachment item; `POST /items/<key>/file` with `md5`, `filename`, `filesize`, `mtime`
   and the header `If-None-Match: *` (a reply `{"exists":1}` means the file is already
   stored); upload `prefix + bytes + suffix` to the returned URL; then register the
   `uploadKey`. Read back the `md5` again.
4. When moving PDFs between items or libraries, copy and verify each one before
   deleting anything at the source.

## Known traps

- Removing an item from a collection can report success and change nothing. Re-read
  the collection afterwards.
- There is no merge endpoint, and deleting an item through the API is permanent.
- A Web API change reaches a Better BibTeX export only after Zotero desktop syncs.
  Check the `.bib` after the sync, not right after the write.
- A `citationKey` sent when creating an item is not kept: Better BibTeX makes its own
  from its key formula. Fix a wrong key by fixing the metadata (a misspelled creator, a
  missing date), or pin it afterwards by setting the item's `citationKey` field with
  `zot.update_item`.
- Never edit a Better BibTeX auto-exported `.bib` by hand: the next export overwrites
  it. Fix metadata and keys in Zotero.
- If you keep copies of papers in group libraries, set Better BibTeX key uniqueness to
  per library (Settings > Better BibTeX > Citation keys); with the global scope, group
  copies push `a`/`b` suffixes onto your own keys.
- After any key change, compare cited keys with the export by title, not by key
  existence: a cited key can exist and name a different work.

End with the counts (step 4 of "Every subcommand that writes") and the full path of
every file written.
