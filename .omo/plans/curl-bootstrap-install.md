# curl-bootstrap-install - Work Plan

## TL;DR (For humans)

**What you'll get:** The repo becomes installable with a single `curl ... | bash` command — no cloning, no manual steps. The `install.sh` becomes a tiny bootstrap that clones the repo at the tagged version and hands off to a `scripts/deploy.sh` that contains all the real setup logic. First release tagged `v0.0.1`.

**Why this approach:** One-script curl install is the industry standard (rustup, nvm, oh-my-zsh). The bootstrap stays small (~35 lines) and version-pinned through the tag URL; the deploy logic stays unchanged in `scripts/deploy.sh`. No module split, no complexity — just a thin wrapper that clones and delegates.

**What it will NOT do:** Split install.sh into modules (deferred), change any template/component logic, modify backup.sh/healthcheck.sh behavior, change Ansible roles, or add test frameworks.

**Effort:** Small
**Risk:** Low — bootstrap is a self-contained wrapper; deploy.sh is a verbatim copy of current install.sh phase logic.
**Decision to sanity-check:** That `scripts/deploy.sh` is the right place for the deploy logic.

## Scope

### MUST have
1. Rewrite `install.sh` as a ~35-line bootstrap that checks if `templates/infra/` exists relative to itself — if not (piped via curl), clones the repo at `$VERSION` (default: `v0.0.1`) to `~/dev/01-core-infra` and `exec`s the cloned `install.sh`; if yes (already in cloned repo), `exec bash scripts/deploy.sh`.
2. Create `scripts/deploy.sh` containing the full deploy logic currently in `install.sh` (lines 6-451) — with its own shebang, `set -euo pipefail`, REPO_DIR computed from `BASH_SOURCE[0]/..`, plus the PATH export, logging, and all phases (0–4).
3. Update `AGENTS.md` to document the bootstrap → deploy.sh architecture and the curl install method.
4. Create annotated git tag `v0.0.1` on current HEAD.
5. Verify all `.sh` files pass `bash -n`.
6. Run `./install.sh` end-to-end to confirm idempotent behavior.

### MUST NOT have (guardrails)
- Do NOT split install.sh into modules (the existing `fix-install-sh-refactor` plan covers that separately).
- Do NOT change the deploy logic in any way — deploy.sh is a verbatim copy of current install.sh phases (byte-identical output).
- Do NOT modify backup.sh, healthcheck.sh, or their behavior.
- Do NOT touch templates/ content, docker-compose files, Ansible roles, or CI workflows.
- Do NOT add test frameworks or linters.
- Do NOT delete or rename any existing files outside what this plan creates.

## Verification strategy
> Zero human intervention — all verification is agent-executed.
- **Test decision:** tests-after (shell scripts verified by `bash -n` + end-to-end run)
- **Evidence:** `.omo/evidence/` for each task's QA output

## Execution strategy

### Parallel execution waves
**Wave 1** (sequential — tight coupling, deploy.sh must exist before bootstrap can reference it):
- Todo 1: Create `scripts/deploy.sh`
- Todo 2: Rewrite `install.sh` as bootstrap

**Wave 2** (parallel — independent):
- Todo 3: `bash -n` syntax verification
- Todo 4: Update AGENTS.md

**Wave 3** (final — after all other work):
- Todo 5: Tag `v0.0.1`
- Todo 6: Run `./install.sh` end-to-end

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
|---|---|---|---|
| 1 | None | 2 | None |
| 2 | 1 | 3, 4 | None |
| 3 | 2 | 5 | 4 |
| 4 | 2 | 5 | 3 |
| 5 | 3, 4 | 6 | None |
| 6 | 5 | — | None |

## Todos

- [x] 1. Create `scripts/deploy.sh` with the full deploy logic from current `install.sh`
  What to do / Must NOT do:
    - Create `scripts/` dir at repo root if it doesn't exist.
    - Create `scripts/deploy.sh` containing ALL deploy logic from current `install.sh` lines 6–451 (REPO_DIR through "Deployment completed successfully"), adapted:
      - Shebang line: `#!/bin/bash`
      - `set -euo pipefail`
      - Compute REPO_DIR from BASH_SOURCE: `SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); REPO_DIR=$(cd "$SCRIPT_DIR/.." && pwd)` — this resolves `scripts/..` → repo root.
      - Keep all other variables, PATH export, logging setup, and ALL phases (0–4) exactly as they are in current install.sh lines 10–451.
      - The `chmod +x` line (line 406) should reference `"$REPO_DIR/install.sh" "$REPO_DIR/backup.sh" "$REPO_DIR/healthcheck.sh" "$REPO_DIR/scripts/deploy.sh"`.
    - Do NOT change any deploy logic — byte-identical phase execution.
    - Do NOT add `#!/bin/bash` to any other file.
    - Do NOT include the `source` lines that the old plan proposed — this is a monolithic file.
  Parallelization: Wave 1 | Blocked by: None | Blocks: Todo 2
  References: install.sh:6-451 (all deploy logic to copy), install.sh:10-15 (REPO_DIR/BASE_DIR/TEMPLATES set-up), install.sh:22-28 (PATH export + logging), install.sh:30-42 (Phase 0 proxy), install.sh:44-94 (Phase 0a tools), install.sh:96-112 (omo), install.sh:114-138 (fish), install.sh:140-175 (PATH config), install.sh:177-272 (ollama), install.sh:274-303 (docker + git config), install.sh:305-403 (deploy + manifest), install.sh:405-432 (systemd + cron), install.sh:434-451 (mesh sync + done)
  Acceptance criteria (agent-executable): `ls scripts/deploy.sh` exits 0; `bash -n scripts/deploy.sh` exits 0; `grep -c 'REPO_DIR.*BASH_SOURCE.*\.\.' scripts/deploy.sh` == 1 (correct REPO_DIR derivation); `grep -c 'set -euo pipefail' scripts/deploy.sh` == 1; `wc -l < scripts/deploy.sh` >= 400 (contains all phases).
  QA scenarios:
    - Happy: deploy.sh exists, `bash -n` passes, contains all phase keywords ("tool-setup", "ollama", "docker", "deploy_pure", "systemd", "mesh sync").
    - Failure: deploy.sh missing, `bash -n` fails, or deploy.sh has fewer than 400 lines.
    Evidence: `.omo/evidence/task-1-curl-bootstrap-install.log`
  Commit: Y | feat(scripts): extract deploy logic into scripts/deploy.sh

- [x] 2. Rewrite `install.sh` as bootstrap script
  What to do / Must NOT do:
    - Replace the entire contents of `install.sh` with:

```bash
#!/bin/bash
# 01-core-infra bootstrap installer
# Usage (from GitHub at a tagged release):
#   curl -o- https://raw.githubusercontent.com/Aldo-f/01-core-infra/v0.0.1/install.sh | bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$REPO_DIR/templates/infra" ]; then
  # Running outside a cloned repo (e.g. curl | bash) — clone and re-exec
  VERSION="${VERSION:-v0.0.1}"
  INSTALL_DIR="$HOME/dev/01-core-infra"

  # Guard: abort if install directory already exists
  if [ -d "$INSTALL_DIR" ]; then
    echo "ERROR: $INSTALL_DIR already exists."
    echo "Remove it first or run from within the cloned repo."
    exit 1
  fi

  # Guard: validate tag exists before cloning
  echo "=== 01-core-infra bootstrap ($VERSION) ==="
  if ! git ls-remote --tags --exit-code https://github.com/Aldo-f/01-core-infra.git "$VERSION" >/dev/null 2>&1; then
    echo "ERROR: Tag $VERSION not found. Check the version and try again."
    exit 1
  fi

  mkdir -p "$HOME/dev"
  git clone --branch "$VERSION" --single-branch --depth 1 https://github.com/Aldo-f/01-core-infra.git "$INSTALL_DIR"
  echo "Repository cloned to $INSTALL_DIR"
  echo "Starting deployment..."
  exec bash "$INSTALL_DIR/install.sh"
fi

# Running from within the cloned repo — hand off to deploy
exec bash "$REPO_DIR/scripts/deploy.sh"
```
    - Keep the file executable: `chmod +x install.sh`.
    - Do NOT leave any of the old deploy logic in install.sh.
    - Do NOT add any other files or change the shebang.
    - The fallback clone (when tag not found) uses `main` branch.
  Parallelization: Wave 1 | Blocked by: Todo 1 | Blocks: Todo 3, 4
  References: install.sh (current file, will be overwritten)
  Acceptance criteria (agent-executable): `bash -n install.sh` exits 0; `wc -l < install.sh` <= 50; `grep -c 'exec.*scripts/deploy.sh' install.sh` == 1; `grep -c 'git clone' install.sh` == 1; `grep -c 'git ls-remote' install.sh` == 1; `grep -c 'templates/infra' install.sh` == 1 (the check); `grep -c '\-\-depth 1' install.sh` == 1 (shallow clone).
  QA scenarios:
    - Happy: Bootstrap is <50 lines, `bash -n` passes, has clone + exec + guard logic.
    - Happy: `bash install.sh` with `INSTALL_DIR` existing → exits 1 with error message.
    - Happy: `VERSION=nonexistent bash install.sh` → exits 1 with "Tag not found" message.
    - Failure: `bash -n` fails, or file still contains deploy logic (>100 lines).
    Evidence: `.omo/evidence/task-2-curl-bootstrap-install.log`
  Commit: Y (included with Todo 1)

- [x] 3. Run `bash -n` syntax verification on all shell scripts
  What to do / Must NOT do:
    - Run `bash -n install.sh` — must exit 0.
    - Run `bash -n scripts/deploy.sh` — must exit 0.
    - Run `bash -n backup.sh` — must exit 0.
    - Run `bash -n healthcheck.sh` — must exit 0.
    - Run `bash -n templates/systemd/app-deploy-systemd` — must exit 0.
    - Run `bash -n templates/systemd/app-install-cron` — must exit 0.
    - Do NOT modify any files — pure verification.
  Parallelization: Wave 2 | Blocked by: Todos 1, 2 | Blocks: Todo 5
  References: install.sh, scripts/deploy.sh, backup.sh, healthcheck.sh, templates/systemd/app-deploy-systemd, templates/systemd/app-install-cron
  Acceptance criteria (agent-executable): All `bash -n` commands exit 0.
  QA scenarios:
    - Happy: All 6 scripts pass `bash -n` with exit code 0.
    - Failure: Any script fails `bash -n`.
    Evidence: `.omo/evidence/task-3-curl-bootstrap-install.log`
  Commit: N (verification step)

- [x] 4. Update AGENTS.md to document bootstrap pattern
  What to do / Must NOT do:
    - Add a section at the top (after existing "## Deployment"): `## One-Command Install` with the curl command example.
    - Update the "Source of Truth" section to mention `scripts/deploy.sh` as the real installer.
    - Add a `## Scripts` section if not present documenting:
      - `install.sh` — bootstrap: clones repo if needed, then execs `scripts/deploy.sh`
      - `scripts/deploy.sh` — the full install logic (all phases 0–4)
    - Do NOT rewrite the entire AGENTS.md — append and update minimally.
    - Do NOT remove or change existing section content.
  Parallelization: Wave 2 | Blocked by: Todos 1, 2 | Blocks: Todo 5
  References: AGENTS.md (current: 126 lines)
  Acceptance criteria (agent-executable): `grep -q 'curl.*raw.githubusercontent' AGENTS.md` exits 0; `grep -q 'scripts/deploy.sh' AGENTS.md` exits 0; `grep -q 'bootstrap' AGENTS.md` exits 0.
  QA scenarios:
    - Happy: AGENTS.md mentions the curl command, deploy.sh, and bootstrap.
    - Failure: No curl command or deploy.sh mentioned.
    Evidence: `.omo/evidence/task-4-curl-bootstrap-install.log`
  Commit: Y | docs(AGENTS.md): document curl bootstrap install method

- [x] 5. Create git tag `v0.0.1`
  What to do / Must NOT do:
    - Run `git tag -a v0.0.1 -m "v0.0.1 — first release with curl | bash bootstrap"`
    - Confirm tag is created: `git tag -l 'v0.0.1'` shows the tag.
    - Do NOT push the tag to remote (user does that manually when ready).
    - Do NOT create any other tags.
  Parallelization: Wave 3 | Blocked by: Todos 3, 4 | Blocks: Todo 6
  References: (git tag operation)
  Acceptance criteria (agent-executable): `git tag -l 'v0.0.1'` exits 0 and outputs `v0.0.1`.
  QA scenarios:
    - Happy: Tag created, `git tag -l` shows it.
    - Failure: Tag creation fails or doesn't persist.
    Evidence: `.omo/evidence/task-5-curl-bootstrap-install.log`
  Commit: N (tag, not a code change)

- [x] 6. Run `./install.sh` end-to-end to verify everything works
  What to do / Must NOT do:
    - Run `cd ~/dev/01-core-infra && ./install.sh`
    - Verify it completes with exit code 0 and the last log line is "Deployment completed successfully".
    - Verify runtime dirs are populated (e.g., `ls portainer/docker-compose.yml`, `ls plex/docker-compose.yml`, etc.).
    - Do NOT modify any files — pure execution test.
    - If this is the local dev machine, the install will re-run all phases (tools, docker, ollama, etc.) which is fine — it's idempotent.
  Parallelization: Wave 3 | Blocked by: Todos 1-5 | Blocks: None
  References: install.sh, scripts/deploy.sh
  Acceptance criteria (agent-executable): `./install.sh` exits 0; `grep -q 'Deployment completed successfully' "$(ls -t logs/install-*.log | head -1)"` exits 0.
  QA scenarios:
    - Happy: install.sh exits 0, deploy.log shows all phases OK.
    - Failure: install.sh exits non-zero or deploy log shows errors.
    Evidence: `.omo/evidence/task-6-curl-bootstrap-install.log`
  Commit: N (verification step)

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE.
- [x] F1. Plan compliance audit — verify all 6 todos completed with acceptance criteria
- [x] F2. Code quality review — verify bash -n passes, no shellcheck violations in new/changed files
- [x] F3. Real manual QA — run `bash -n install.sh scripts/deploy.sh backup.sh healthcheck.sh` on the final state
- [x] F4. Scope fidelity — confirm no templates/, docker-compose, Ansible, CI, or backup.sh/healthcheck.sh logic was changed

## Commit strategy
1. `feat(scripts): extract deploy logic into scripts/deploy.sh; rewrite install.sh as bootstrap`
   (combines Todo 1 + 2 — deploy.sh creation + install.sh rewrite in one atomic commit)
2. `docs(AGENTS.md): document curl bootstrap install method`
   (Todo 4)

Tag `v0.0.1` is applied after both commits, on the resulting HEAD.

## Success criteria
- [x] `install.sh` is ≤40 lines, passes `bash -n`, and has the clone-check- exec pattern
- [x] `scripts/deploy.sh` exists, is ≥400 lines, passes `bash -n`, contains all deploy phases unchanged
- [x] `backup.sh` and `healthcheck.sh` pass `bash -n` unchanged
- [x] AGENTS.md documents the curl install command and the bootstrap→deploy.sh architecture
- [ ] Git tag `v0.0.1` exists locally
- [ ] `./install.sh` runs end-to-end with exit 0, showing "Deployment completed successfully"
