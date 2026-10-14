---
description: Bring the task's notes up to date before /clear or the end of a session
---

Wrap up the current task so that a fresh session can resume from files alone.

1. Identify the notes file of the task we worked on (`notes/<task>.md`). If it is not
   clear which one, ask me.
2. Update it:
   - Progress: what landed, with commit hashes and measured numbers;
   - Decisions: any choice made this session, numbered, with its reason;
   - Surprises: symptom, cause, fix;
   - Follow-ups: what is left, and why.
   Use precise language: numbers and conditions, not adjectives.
3. Lessons: for anything a future session would otherwise rediscover, add an entry to
   `notes/lessons.md` with the next free number (symptom, cause, fix, rule). If a lesson
   holds for every project, suggest a line for `~/.claude/CLAUDE.md`, but do not edit
   that file yourself.
4. Show `git status`, and offer to commit the notes together with the work. Do not push.
5. End with three lines: current state, next step, and the file to read to resume.
