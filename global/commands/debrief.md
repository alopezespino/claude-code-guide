---
description: Turn a meeting recording into a transcript, a summary and GitHub issues
argument-hint: <audio file | --resume file.cache.json>
---

Process the meeting recording `$ARGUMENTS` with
[debriefr](https://github.com/alopezespino/debriefr). If no file is given, list the
audio files in the project root and in `inbox/`, and ask me which one.

Prerequisites, once per machine (details in the debriefr README):

```bash
git clone https://github.com/alopezespino/debriefr.git
cd debriefr
python3 -m venv .venv
source .venv/bin/activate
pip install -e '.[mlx]'  # local Whisper, Apple Silicon; '.[local]' elsewhere
hf auth login            # paste a Hugging Face Read token
security add-generic-password -a "$USER" -s anthropic_api_key -w
gh auth login            # only for the GitHub sync
```

- ffmpeg comes with debriefr (imageio-ffmpeg); there is nothing else to install.
- On huggingface.co, accept the licenses of `pyannote/speaker-diarization-3.1`,
  `pyannote/segmentation-3.0` and `pyannote/wespeaker-voxceleb-resnet34-LM`.
- Add this to `~/.zshrc` so the summary step finds the key. Without a key, use
  `--no-summary` and let step 6 write the summary in this session:
  ```bash
  export ANTHROPIC_API_KEY=$(security find-generic-password \
    -a "$USER" -s anthropic_api_key -w)
  ```
- Instead of a local Whisper, `pip install -e .` with a free Groq key (`GROQ_API_KEY`)
  transcribes in the cloud; the audio then leaves your machine.

Rules for every run:

- Meeting audio, transcripts, voice clips and voiceprints are confidential. Never
  commit, push or share them, or a summary, without my approval.
- Activate the venv (`source <debriefr>/.venv/bin/activate`) before any `debriefr`
  command. If you cannot find it, ask me where it is.
- Run every command from the project root: `samples/` and `enrollments/` are relative
  to the current directory. Leave the audio file where it is until the run is done.

1. Find the project. Look for `project.yaml` in the current directory and its parents.
   If there is none, offer to create one at the project root from this example, and ask
   me for the names, bios and GitHub handles:
   ```yaml
   name: myproject            # optional; default is the folder name
   transcript_dir: meetings   # transcripts and summaries go here
   collaborators:
     Alex:
       bio: Coauthor, leads the data work.  # used verbatim in the summary
       github: alex-gh                      # issue assignee; null if none
     Sam:
       bio: Coauthor, writes the model.
       github: null
   default_participants: [Alex, Sam]
   cleanup: archive-all       # moves audio and transcripts to .audio-archive/
   github:                    # omit to stop after the summary
     repo: owner/repo
     project: null            # Project v2 number, set in step 8
   ```
   Check that `.gitignore` lists `.audio-archive/`, `samples/`, `enrollments/` and
   `*.cache.json`; offer to add what is missing.
2. Ask me who attended (if not `default_participants`), the language, and whether I
   want to read the transcript first or have this session write the summary.
3. Run:
   ```bash
   debriefr transcribe <audio> [--participants Alex Sam] [--language es]
   ```
   For a transcript review or a summary written here, add
   `--no-summary --cleanup archive-audio`, so the transcript stays in `transcript_dir`
   instead of moving to `.audio-archive/` (pruned after 7 days).
4. If it stops with `status: needs_sampling`, some speakers have no voiceprint. It saved
   one clip of about 45 s per unknown speaker (`samples/SPEAKER_XX.wav`) and a cache
   file. For each clip:
   - ask me to play it (`afplay` on macOS, `aplay` on Linux) and say who it is;
   - wait until I confirm the clip holds one voice only (I may trim it first): a mixed
     clip degrades every later match;
   - then rename and enroll it:
     ```bash
     mv samples/SPEAKER_02.wav samples/Alex.wav
     debriefr enroll --name Alex --audio samples/Alex.wav
     ```
     Enrolling replaces that person's voiceprint. To keep earlier clips, pass all of
     them after a single `--audio` flag.

   Then resume, which re-runs only the identification (seconds, not minutes):
   ```bash
   debriefr transcribe --resume <file.cache.json> [same flags as step 3]
   ```
   If I cannot name a speaker, resume with `--skip-sampling`; the label stays unknown.
5. If I asked to review the transcript, print the `.txt` path and wait. Apply each
   correction to both the `.txt` and the `.json`.
6. Summary written here (only after `--no-summary`):
   - read the `.txt` and the bundled summary prompt,
     `debriefr/prompts/summary_default.md` in the debriefr clone;
   - begin with `Known participants (use these bios verbatim):` and the `bio` from
     `project.yaml` of each speaker present;
   - follow the prompt exactly, in the transcript's language, including the
     `## Action Items` table (`# | Owner | Task | Due | Priority | Notes`);
   - the first line it asks for is `reference: <slug>`: drop that line, write
     `<transcript_dir>/<YYYY-MM-DD>_<slug>.md`, and rename the `.txt` and `.json` to
     the same stem.
7. Stop for my edits. Print the summary's full path and list the action items that will
   not sync cleanly: owners not in `collaborators` (no assignee), joint owners
   ("Alex & Sam"), private notes that should not appear on a shared board, and rows that
   form one deliverable and could be one issue with a checklist. Priority `done` keeps a
   row without creating an issue. Do not continue until I say the summary is final.
8. Sync, only if `project.yaml` has a `github:` section and I want it. First check that
   the summary has the action-items table and that `github.project` is a number. If it
   is `null`, offer to create the board, then write its number into `project.yaml`
   (iteration fields can only be added in the browser):
   ```bash
   debriefr sync-issues --setup --title "myproject action items"
   ```
   Then dry-run, show me the plan, and wait for my approval:
   ```bash
   debriefr sync-issues <summary.md> --dry-run
   ```
   After approval, run it with `--yes`. Without it the command stops at a
   `Proceed? [y/N]` prompt that a non-interactive shell cannot answer:
   ```bash
   debriefr sync-issues <summary.md> --yes
   ```
   The sync writes `<!-- synced:#N -->` markers into the summary. Keep them: they stop
   a later run from creating duplicate issues.
9. Report the full paths of the summary, the transcripts and any new voiceprints, who
   was enrolled, and how many issues were created and updated. Remind me that a commit
   message with `closes #N` closes issue N. Do not commit or push without my approval.
