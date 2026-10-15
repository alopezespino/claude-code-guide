---
description: Report which assigned GitHub issues are overdue or due soon, how far each has progressed, and which @-mentions of me are unanswered
argument-hint: [N | all] [owner/repo]
---

> Example command from
> [claude-code-guide](https://github.com/alopezespino/claude-code-guide),
> not built into Claude Code. Edit this file to change what the command does.

Check progress on the open issues of a GitHub repository where I coordinate other
people's work (research assistants, students, coauthors). This command is read-only:
never edit, comment on, label or close an issue, and never change a project board.

## Arguments

`$ARGUMENTS`, in any order:

- nothing: every overdue issue plus those due within the next 7 days;
- a number `N`: an `N`-day window instead of 7;
- `all`: every open issue, with or without a due date;
- `owner/repo`: the repository to check. Default: the repository of the current
  folder, from `gh repo view --json nameWithOwner --jq .nameWithOwner`.

Below, `$REPO` is that repository and `$ME` is my GitHub login, from
`gh api user --jq .login`. Pass `--repo $REPO` (or the full `repos/$REPO` path) to every
command, so the result does not depend on the current folder.

## Issue conventions this command assumes

Edit this block to match how you write issues; the steps read only what it lists.

- The body has a line `**Due:** YYYY-MM-DD`. `ASAP (No later than YYYY-MM-DD)` means
  that date; `ASAP` or `TBD` alone means no date.
- Optionally a line `**Start:** YYYY-MM-DD`.
- The steps of the task are a checklist of `- [ ]` and `- [x]` boxes.
- Optionally the body links the task's folder in the repository (a path such as
  `tasks/<folder>/`), where the assignee pushes their work.

## Steps

1. **Today's date.** Run `date +%F` and state the date at the top of the report, so the
   day counts can be checked.

2. **Pull the open issues.**
   ```bash
   gh issue list --repo $REPO --state open --limit 100 \
     --json number,title,url,assignees,labels,milestone,updatedAt,body,comments
   ```
   If the number of issues returned equals the limit, say so and rerun with a higher
   `--limit`, so no issue is silently left out.
   From each body read the due date, the start date, the number of checked and unchecked
   boxes, and the task folder (the first match of `tasks/[A-Za-z0-9_-]+/`; change the
   pattern to your layout). Always read the folder from the body; never keep a fixed map
   from issue to folder, so renamed or new tasks are still found.

3. **Compute per issue:** `days_to_due` = due date minus today (negative means overdue);
   `progress` = checked boxes / all boxes; `last_activity` = the latest of `updatedAt`,
   the latest comment and the latest commit (step 5).

4. **Select the issues in scope:** overdue, or due within the window. Leave out issues
   with no date unless the argument is `all`.

5. **Gather each in-scope issue's activity.**
   - Comments: their count, and the author, date and first line of the latest one or
     two. Comments by `$ME` (reminders, instructions) are not activity by the assignee.
   - Commits to the task folder since the start date (skip if the body links no folder):
     ```bash
     gh api "repos/$REPO/commits?path=tasks/<folder>/&since=<start>T00:00:00Z" \
       --jq '.[] | [.commit.author.date[0:10],
         (.author.login // .commit.author.name),
         (.commit.message | split("\n")[0])] | join("  ")'
     ```
   - Commits and pull requests that mention the issue:
     ```bash
     gh api repos/$REPO/issues/<N>/timeline \
       --jq '.[] | select(.event=="referenced" or .event=="cross-referenced")'
     ```

6. **Give each issue a status**, with the reason in one short phrase:
   - 🟢 **on track:** the checklist is advancing or there are recent commits or comments,
     and the issue is not overdue or is essentially finished (all boxes checked, waiting
     for review).
   - 🟡 **watch:** due soon with little progress, or overdue while the assignee is
     visibly working (commits or comments in the last two days).
   - 🔴 **nudge:** overdue or due within a day, with little or no progress and no recent
     activity by the assignee. No commits, no checked boxes and no comments is itself
     the signal.

7. **Unanswered mentions of me.**
   ```bash
   gh api "search/issues?q=repo:$REPO+mentions:$ME" \
     --jq '.items[] | {number, title, state}'
   ```
   For each hit, read the body and comments (`gh issue view <N> --repo $REPO --json
   body,comments`) and find the text by someone other than `$ME` that contains `@$ME`.
   A mention is unanswered when no comment by `$ME` on that issue comes after it
   (GitHub comments have no threads, so a later reply anywhere in the issue counts).
   Add each unanswered mention to the session's task list as "Reply to @author on #N
   (short title)", with the date, a one-line quote and the comment's URL; skip it if the
   same task is already there.

8. **Print the report**, 🔴 first, then 🟡, then 🟢, one block per issue:
   ```
   🔴 #15 Clean the survey data, @ra-handle, due 2026-07-02 (2 days overdue), 0/3 done
      why: overdue, no checked boxes, no commits or comments since it was opened
      last activity: none
   ```
   Then:
   - **Needs reply:** one line per unanswered mention
     (`#N, @author, date: "quote" -> URL`), or "none".
   - **Nudge list:** `assignee, issue, what is stalled`, ready to send in the issue or
     raise at the next meeting.

## Notes

- An issue with no assignee (for example, before the person accepted the repository
  invitation): name the intended owner if the body or milestone says who, as
  "unassigned (intended: name)".
- Keep the report short: it should answer "whom do I need to nudge?" in ten seconds.
