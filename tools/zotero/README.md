# Zotero scripts

Example scripts from
[claude-code-guide](https://github.com/alopezespino/claude-code-guide) that the
[`/zotero`](../../global/commands/zotero.md) command can run instead of writing
helpers from scratch each time. They use the Zotero Web API v3 and are written for
macOS (credentials in the Keychain). Read them before you run them, and edit them to
fit your library.

| Script | What it does |
|---|---|
| `zotero_api.py` | Shared client, local index, download queue; `sync-index [--full]`, `search`, `stats` |
| `zotero_update_meta.py` | `<file.bib> [--fields a,b]`: update Zotero metadata from a `.bib` |
| `zotero_update_paper.py` | `--check-all`, `--citation-key k` or `--tag t`: find newer or published versions of working papers |

## Setup

```bash
python3 -m venv ~/.venvs/zotero
~/.venvs/zotero/bin/pip install -r tools/zotero/requirements.txt
security add-generic-password -a "$USER" -s zotero_api_key -w
security add-generic-password -a "$USER" -s zotero_user_id -w
```

Each `security` line prompts for the value. Create the key at
https://www.zotero.org/settings/keys with library and write access (and access to any
group you use); the same page shows your numeric user id. The scripts read both values
from the Keychain at the moment of use and never print them. If a Keychain entry is
missing they fall back to the environment variables `ZOTERO_API_KEY` and
`ZOTERO_USER_ID` and print a warning: environment variables end up in shell history,
logs and child processes, so use them only where there is no Keychain.

Run the scripts from the project folder, so the relative paths below land there:

```bash
~/.venvs/zotero/bin/python /path/to/claude-code-guide/tools/zotero/zotero_api.py \
  sync-index
```

## Configuration

Optional. Put a `zotero-config.json` in the folder you run from (or pass
`--config <file>`). Every key is optional; these are the defaults:

```json
{
  "index_path": "notes/zotero-index.json",
  "queue_path": "notes/zotero-downloads.md",
  "proxy_prefix": "",
  "email": ""
}
```

- `index_path`: local cache mapping citation keys and DOIs to item keys. A group
  library gets its own file (`zotero-index-group-<id>.json`).
- `queue_path`: Markdown file of published papers to download by hand.
- `proxy_prefix`: your library's proxy login prefix, if it has one, for example
  `https://proxy.example.edu/login?url=`. Queue links become
  `<proxy_prefix>https://doi.org/<DOI>`. Empty means plain DOI links.
- `email`: a contact address sent to CrossRef and OpenAlex, and required by
  Unpaywall. Empty means Unpaywall is skipped.

`--index` and `--queue` override the paths for one run. `--group <name or id>` works on
a group library instead of your personal one.

## Every write: read, dry run, approval, apply, re-read

1. **Read.** Each script syncs the index from the API first (`--no-sync` skips it) and
   re-reads every item it will compare or change.
2. **Dry run.** `--dry-run` prints the full plan as a table and writes nothing: no
   Zotero change, no download, no queue row, no index file.
3. **Approval.** Without `--dry-run`, the script asks before writing. In a shell
   without a terminal (as when Claude Code runs it) it refuses unless you pass `--yes`,
   so the sequence is always: dry run, you read the table, then `--yes`.
4. **Apply.** Each update sends the item's version, so the API refuses a write if the
   item changed since it was read.
5. **Re-read.** Every changed item is fetched again and checked: metadata fields must
   hold the new values, and an uploaded PDF must be listed under its item with the
   same md5 as the local file. Failures are reported and the script exits 1.

## Examples

`python` below means `~/.venvs/zotero/bin/python`, run from the
`tools/zotero` folder or with the full path to each script.

Update the index (incremental; `--full` rebuilds it):

```bash
python zotero_api.py sync-index
python zotero_api.py search doe2020trade
```

Fix titles and DOIs from a `.bib`:

```bash
python zotero_update_meta.py refs.bib --fields title,DOI --dry-run
python zotero_update_meta.py refs.bib --fields title,DOI --yes
```

Entries are matched by citation key, then DOI, then title plus authors and year. Rows
matched by title only are flagged in the output; check them. Unmatched entries are
listed and never created.

Check working papers (items of type report, preprint or manuscript):

```bash
python zotero_update_paper.py --check-all --dry-run
python zotero_update_paper.py --citation-key doe2020trade --yes
```

| Finding | Action |
|---|---|
| Newer working-paper version | Download and attach its PDF |
| Published, open publisher version | Update metadata, download and attach |
| Published, only the accepted manuscript open | Update metadata, queue |
| Published, paywalled | Update metadata, queue; never an open preprint as a substitute |

Changing a working paper to a journal article removes the fields a journal article
cannot hold (institution, report number); the dry run lists the non-empty ones. An
existing PDF is never overwritten or deleted: after the new PDF is verified, older PDF
attachments are renamed with a `_wp<year>` suffix. Downloads are kept only if the file
starts with `%PDF-`.

PDFs are uploaded with the API's three-step file upload and read back by md5, not with
`pyzotero`'s `attachment_simple`, which can report a failure without raising and leave
no attachment.

## Limits

- Creators are not updated from the `.bib`.
- CrossRef records links between versions only when the publisher or repository
  deposits them, so a newer draft can exist without being found.
- A Web API change reaches a Better BibTeX export only after Zotero desktop syncs.
