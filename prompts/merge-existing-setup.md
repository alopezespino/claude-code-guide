# Prompt: merge these files into an existing Claude Code setup

Use this when `scripts/install-global.sh` skipped files because you already have a
`~/.claude/CLAUDE.md` or `~/.claude/settings.json`. Open a Claude Code session in this
repository, switch to Plan mode (Shift+Tab), and paste the text below.

```text
Merge the starter files in this repository's global/ folder into my existing
Claude Code setup in ~/.claude, without losing anything I already have.

1. Back up first: copy ~/.claude/CLAUDE.md and ~/.claude/settings.json to
   files with a .bak-YYYY-MM-DD suffix next to them. Print the backup paths.
2. Read my existing files and the incoming ones in full before changing
   anything.
3. Classify every incoming rule, permission and hook as one of:
   ADD (new), MERGE (overlaps one of mine and can be combined),
   CONFLICT (contradicts one of mine), SKIP (already covered).
   Never drop or weaken one of my existing rules.
4. Show me the classification as a table. For each CONFLICT, give the two
   versions and a recommendation using these tiebreakers:
   - a rule with a concrete origin beats a bare preference;
   - when a mistake would be unrecoverable, the stricter rule wins;
   - on matters of taste, my existing rule wins;
   - when unsure, keep both, each scoped narrowly.
   Wait for my ruling on every conflict.
5. Only after I approve, write the merged files. Mark the merged section
   with a comment naming its source and today's date.
6. Copy global/hooks/ and global/commands/ files that I do not already have.
   Do not overwrite existing files with the same name; list them instead.
7. Tell me to restart Claude Code. In the new session I will ask you three
   questions that only the merged rules can answer, to verify they loaded.
   If anything is wrong, restore from the backups.
```
