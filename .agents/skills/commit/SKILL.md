---
name: commit
description: Stage only files edited in the current conversation and create a conventional commit with an AI-generated message.
category: Workflow
tags: [git, commits, conventional-commits]
---

Create a conventional commit scoped to files touched in the current conversation.

**Steps**

1. **Identify files edited in this conversation**

   Look back through the current conversation for any files you created or modified using the Write, Edit, or NotebookEdit tools. Collect the unique set of file paths.

   If the user provided explicit paths as arguments (`$ARGUMENTS`), use those instead.

   If no files were edited and no arguments were given, run `git status` and tell the user there is nothing to commit from this conversation, then stop.

2. **Check those files have actual changes**

   Run `git status` and cross-reference with your list. Only keep files that appear as modified, added, or untracked. Ignore any that are already clean.

   If the intersection is empty, tell the user and stop.

3. **Stage only those files**

   Run `git add -- <file1> <file2> ...` with the exact paths identified above. Do NOT use `git add -A` or `git add .`.

4. **Review what will be committed**

   Run `git diff --cached --stat` and `git diff --cached` to get the full picture of staged changes.

5. **Generate the commit message**

   Write a commit message following the Conventional Commits specification:

   ```
   <type>[optional scope]: <description>

   [optional body]

   [optional footer(s)]
   ```

   **Types** (pick the most specific one):
   - `feat` — new feature or capability
   - `fix` — bug fix
   - `docs` — documentation only
   - `style` — formatting, no logic change
   - `refactor` — restructure without behavior change
   - `perf` — performance improvement
   - `test` — add or fix tests
   - `chore` — maintenance, dependencies, tooling
   - `ci` — CI/CD configuration
   - `build` — build system or external dependencies

   **Scope** — the layer or component affected (e.g. `terraform`, `platform`, `clusters`, `apps`, `ci`, `docs`, `script`). Use the repo's 4-layer structure as a guide.

   **Description rules**:
   - Imperative mood: "add" not "added"
   - Lowercase first letter
   - No trailing period
   - 72 chars max on the first line

   **Body**: include when the *why* isn't obvious from the description. Wrap at 72 chars.

   **Footer**: use `BREAKING CHANGE:` for breaking changes; `Closes #N` for issues.

6. **Commit**

   Run the commit using a HEREDOC to preserve formatting:
   ```bash
   git commit -m "$(cat <<'EOF'
   <generated message>
   EOF
   )"
   ```

7. **Confirm**

   Show the result of `git log -1 --oneline` so the user can see the commit was created.

**Guardrails**
- Never skip pre-commit hooks (`--no-verify`)
- Never amend a previous commit — always create a new one
- Do not commit files that look like secrets (`.env`, credential files)
- If pre-commit hooks fail, fix the issue and re-commit; do NOT bypass
