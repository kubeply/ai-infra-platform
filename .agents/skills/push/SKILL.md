---
name: push
description: Fetch origin, rebase local commits on top of the latest remote changes if needed, then push the current branch.
category: Workflow
tags: [git, push, rebase]
---

Fetch, rebase if needed, and push the current branch to origin.

**Steps**

1. **Verify there is something to push**

   Run `git status` and `git log @{u}..HEAD --oneline` to check if there are local commits ahead of the remote.

   If there are uncommitted changes in the working tree, stop and tell the user to commit first (suggest `$commit`).

   If there are no local commits ahead of the remote, tell the user there is nothing to push and stop.

2. **Fetch origin**

   Run `git fetch origin` to get the latest remote state without modifying the working tree.

3. **Check if rebase is needed**

   Run `git log HEAD..origin/main --oneline` to see if the remote has commits the local branch does not.

   - If the output is empty: no rebase needed, skip to step 5.
   - If there are remote commits: proceed to step 4.

4. **Rebase onto origin/main**

   Run `git rebase origin/main`.

   If the rebase produces conflicts:
   - Show the conflicting files to the user
   - Stop and tell the user to resolve conflicts manually, then run `$push` again
   - Do NOT attempt to resolve conflicts automatically

5. **Push**

   Run `git push origin HEAD:main`.

6. **Confirm**

   Show `git log origin/main -1 --oneline` so the user can see their commit is now on the remote.

**Guardrails**
- Never force-push (`--force`, `--force-with-lease`) unless the user explicitly asks
- Never push directly to a protected branch other than what was already intended
- If rebase conflicts occur, stop immediately — do not auto-resolve
- Do not push if there are uncommitted changes
