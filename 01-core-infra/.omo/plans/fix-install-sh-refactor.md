# fix-install-sh-refactor - Work Plan

## TL;DR (For humans)
<!-- Fill this LAST, after the detailed plan below is written, so it summarizes the REAL plan. -->
<!-- Plain English for a non-engineer: NO file paths, NO todo numbers, NO wave/agent/tool names. -->

**What you'll get:** A refactored `install.sh` split into 6 focused modules under `scripts/`, 8 bug fixes (pre-commit hook, cron template, destructive cron-install helper, silent deploy failures, wrong mesh-sync command chain, triple-duplicated Ollama parser, unnecessary repeated git config/sudoers writes), a new `scripts/smoke-test.sh` for post-deploy verification, and an updated `AGENTS.md` that matches the new structure.

**Why this approach:** Module split first, then fix bugs in the modules — avoids the mess of patching install.sh then re-extracting. Three standalone bugs (pre-commit, cron template, cron-install helper) are independent and can be done in parallel with the split prep.

**What it will NOT do:** Touch any `docker-compose.yml` contents, add a test framework (no Jest/bats/pytest), modify `backup.sh` or `healthcheck.sh` or `repos.manifest.jsonc`, or rename scripts. Deploy output will be byte-identical.

**Effort:** Medium
**Risk:** Medium — module split touches every line of install.sh; `set -euo pipefail` must propagate correctly to sourced modules.
**Decisions to sanity-check:** Module file naming, the `source` chain in install.sh, whether the smoke-test covers enough.

Your next move: review the plan and high-accuracy review results.

---

> TL;DR (machine): Medium effort, medium risk. Fix 8 bugs + split install.sh into 6 scripts/ modules + add smoke-test.sh. 12 todos in 4 waves. Momus + independent Oracle review required before execution.

## Scope
### Must have
1. Fix .husky/pre-commit: assign `$TEMPLATE`, fix quoting, point to correct cron template path.
2. Fix templates/cron/01-core-infra.cron: replace hardcoded `__CORE_INFRA__/` and `aldo` with `__HOME__`/`__USER__`/`__CORE_INFRA__`; remove stray `\x07` bell characters.
3. Fix templates/systemd/app-install-cron: write to temp file then `install` to destination; never `sed -i` on source template.
4. Extract install.sh phases 0a-4 into `scripts/{tool-setup,ollama-setup,docker-setup,deploy,systemd-setup,mesh-sync}.sh`. install.sh becomes a thin orchestrator that `source`s each in order.
5. Add post-copy verification to `deploy_pure()` and `deploy_repo()` in the deploy module.
6. Fix mesh-sync module: `bun install && bun sync`, not `bun install >/dev/null; bun sync`.
7. DRY Ollama API key parser: extract one `read_api_key_file()` function used by all three call sites.
8. Guard `git config --global` behind existence check; guard sudoers install behind content-hash check.
9. Create `scripts/smoke-test.sh`: verify runtime dirs, compose files, manifest repos on correct ref, cron destination has no placeholders, systemd helpers installed.
10. Update AGENTS.md with new `scripts/` structure and module descriptions.
11. Run `./install.sh` + `scripts/smoke-test.sh` to prove everything works.
12. Run `./healthcheck.sh` to confirm Docker services still healthy.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- Do NOT edit any `docker-compose.yml` file contents.
- Do NOT add a test framework (no Jest, bats, pytest, shellcheck CI).
- Do NOT change the runtime behavior of any deploy step (outputs must be byte-identical).
- Do NOT modify `backup.sh`, `healthcheck.sh`, or `templates/infra/repos.manifest.jsonc`.
- Do NOT rename or delete any script outside what this plan creates.
- Do NOT change the component template directory structure.
- Do NOT modify `/etc/sudoers.d/` or systemd service file contents.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: tests-after (shell scripts are verified by running them and checking output/exit codes)
- Evidence: `.omo/evidence/` for each task's QA output

## Execution strategy
### Parallel execution waves
> Target 5-8 todos per wave.

**Wave 1** (parallel — no inter-dependencies): Todos 1, 2, 3 — standalone bug fixes in non-install-sh files.
**Wave 2** (sequential, blocks everything): Todo 4 — module split. Must be done before install.sh bugs can be fixed.
**Wave 3** (parallel — all operate on different extracted modules): Todos 5, 6, 7, 8 — fix bugs in extracted modules.
**Wave 4** (sequential, depends on all fixes): Todos 9, 10, 11, 12 — smoke-test, docs, final verification.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | None | None | 2, 3 |
| 2 | None | None | 1, 3 |
| 3 | None | None | 1, 2 |
| 4 | None | 5, 6, 7, 8 | 1, 2, 3 |
| 5 | 4 | None | 6, 7, 8 |
| 6 | 4 | None | 5, 7, 8 |
| 7 | 4 | None | 5, 6, 8 |
| 8 | 4 | None | 5, 6, 7 |
| 9 | 4, 5, 6, 7, 8 | 12 | 10 |
| 10 | 4, 5, 6, 7, 8 | 12 | 9 |
| 11 | None | 12 | 1, 2, 3, 4 |
| 12 | 9, 10, 11 | — | None |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->

- [ ] 1. Fix .husky/pre-commit — set $TEMPLATE variable, fix quoting, add cron template path
  What to do / Must NOT do:
    - Add `TEMPLATE="templates/cron/01-core-infra.cron"` assignment before the checks.
    - Replace `\"$TEMPLATE"` with `"$TEMPLATE"` on all 4 grep lines (lines 9, 14, 19, 25).
    - Verify `set -euo pipefail` at top doesn't abort on `$TEMPLATE` (it's now assigned).
    - Do NOT change the check logic itself — only fix the broken variable and quoting.
  Parallelization: Wave 1 | Blocked by: None | Blocks: None
  References: .husky/pre-commit:9,14,19,25 (all four grep lines use `\"$TEMPLATE"`)
  Acceptance criteria (agent-executable): `bash -n .husky/pre-commit` exits 0; `bash .husky/pre-commit` exits 0 when the cron template has placeholders and exits 1 when hardcoded paths exist.
  QA scenarios:
    - Happy: `bash .husky/pre-commit` with a cron template that uses `__HOME__`, `__USER__`, `__CORE_INFRA__` — exits 0.
    - Failure: `bash .husky/pre-commit` with a cron template containing `__CORE_INFRA__` — exits 1 with "Detected hardcoded path" message.
    Evidence: `.omo/evidence/task-1-fix-install-sh-refactor.log`
  Commit: Y | fix(husky): set TEMPLATE variable and fix quoting in pre-commit hook

- [ ] 2. Fix templates/cron/01-core-infra.cron — replace hardcoded paths with placeholders, remove bell chars
  What to do / Must NOT do:
    - Replace `aldo` (after bell char) with `__HOME__` on both cron lines (8, 11).
    - Replace `__CORE_INFRA__` with `__CORE_INFRA__` on both cron lines.
    - Remove the stray `\x07` (bell/0x07) character before `aldo` on lines 8 and 11.
    - `HOME=aldo` on line 5 becomes `HOME=__USER__`.
    - Do NOT change any other content or add/remove lines.
    - The file must pass the pre-commit hook after this change (placeholders present, no hardcoded paths).
  Parallelization: Wave 1 | Blocked by: None | Blocks: None
  References: templates/cron/01-core-infra.cron:5,8,11
  Acceptance criteria (agent-executable): `grep -q '__HOME__' templates/cron/01-core-infra.cron` exits 0; `grep -q '__USER__' templates/cron/01-core-infra.cron` exits 0; `grep -q '__CORE_INFRA__' templates/cron/01-core-infra.cron` exits 0; `grep -q '__CORE_INFRA__' templates/cron/01-core-infra.cron` exits 1 (rejected); `grep -q $'\x07' templates/cron/01-core-infra.cron` exits 1 (no bell chars).
  QA scenarios:
    - Happy: Run the 4 grep checks above — all pass.
    - Failure: Any grep check above returns unexpected exit code.
    Evidence: `.omo/evidence/task-2-fix-install-sh-refactor.log`
  Commit: Y | fix(cron): replace hardcoded paths with placeholders and remove bell characters

- [ ] 3. Fix templates/systemd/app-install-cron — stop mutating source of truth
  What to do / Must NOT do:
    - Change the placeholder replacement block (lines 12-20): instead of `sed -i "$SRC"`, write replaced content to a temp file, then `install -m 0644 "$TEMP" "$DEST"`.
    - Pattern: `sed 's|__HOME__|...' "$SRC" > "$TEMP" && install -m 0644 "$TEMP" "$DEST" && rm -f "$TEMP"`.
    - Preserve `$USER` and `$CORE_INFRA` variable derivation logic.
    - Do NOT change the `REAL_HOME` derivation or the fallback logic.
    - Do NOT change the `if [ ! -f "$SRC" ]` guard.
  Parallelization: Wave 1 | Blocked by: None | Blocks: None
  References: templates/systemd/app-install-cron:12-28
  Acceptance criteria (agent-executable): After running the script with `SUDO_USER=aldo`, the source template at `templates/cron/01-core-infra.cron` still contains `__HOME__` placeholders (proving it wasn't mutated). The destination file `/etc/cron.d/01-core-infra` has expanded values.
  QA scenarios:
    - Happy: Run `bash -n templates/systemd/app-install-cron` exits 0. After simulated run (dry mode or with test dirs), source template retains placeholders.
    - Failure: Source template has expanded values after script runs.
    Evidence: `.omo/evidence/task-3-fix-install-sh-refactor.log`
  Commit: Y | fix(systemd): stop sed -i on source template; write to temp file instead

- [ ] 4. Split install.sh into scripts/ modules
  What to do / Must NOT do:
    - Create `scripts/` directory at repo root (git-tracked).
    - Create these module files by extracting the corresponding lines from install.sh. Each module must start with `# shellcheck shell=bash` and NOT have `#!/bin/bash` or `set -euo pipefail` (inherits from parent):
      - `scripts/tool-setup.sh` — `ensure_tool()` function + all `install_*()` functions (lines 47-94) + `OMO_MARKER` block (lines 96-112) + fish default shell block (lines 114-138) + `ensure_bash_path()`/`ensure_fish_path()` (lines 140-175).
      - `scripts/ollama-setup.sh` — `ensure_ollama_api_key()`, `ensure_ollama_api_keys()`, `ollama-keys()`, `select_ollama_model()` + the model pull block (lines 177-272). Plus the DRY'd `read_api_key_file()` function (replacing the three duplicates — see Todo 7).
      - `scripts/docker-setup.sh` — `docker_stack_present()`, `install_docker_stack()`, the check block (lines 274-300), plus `git config` block (lines 302-303).
      - `scripts/deploy.sh` — `runtime_target()`, `deploy_pure()`, `deploy_repo()`, `parse_manifest()` + the pure-infra loop + manifest loop + chmod block (lines 306-407).
      - `scripts/systemd-setup.sh` — Phase 3 systemd + cron blocks (lines 410-432).
      - `scripts/mesh-sync.sh` — Phase 4 mesh sync block (lines 434-444).
    - Rewrite `install.sh` as a thin orchestrator (see Todo 5).
    - Must NOT extract the header (lines 1-28) or the env var setup (lines 10-15).
    - Must NOT change any logic inside the extracted code — exact copy-paste with only the function consolidation from Todo 7.
  Parallelization: Wave 2 | Blocked by: None | Blocks: 5, 6, 7, 8
  References: install.sh:44-444 (all phases), install.sh:47-61 (ensure_tool), install.sh:320-370 (deploy functions), install.sh:306-317 (parse_manifest)
  Acceptance criteria (agent-executable): `ls scripts/*.sh` lists exactly 6 files; each is a non-empty `.sh` file. `grep -c 'source.*scripts/' install.sh` == 6 (one source per module). `bash -n scripts/*.sh` all exit 0.
  QA scenarios:
    - Happy: All 6 module files exist, `bash -n` passes on each, `install.sh` has 6 `source` lines.
    - Failure: Any module file missing, `bash -n` fails, install.sh has syntax errors, or extracted code is missing key functions.
    Evidence: `.omo/evidence/task-4-fix-install-sh-refactor.log`
  Commit: Y | refactor(scripts): split install.sh into 6 focused modules under scripts/

- [ ] 5. Rewrite install.sh as thin orchestrator that sources modules in order
  What to do / Must NOT do:
    - Keep the header (lines 1-28): `#!/bin/bash`, `set -euo pipefail`, env vars (`REPO_DIR`, `BASE_DIR`, `CORE_INFRA`, `TEMPLATES`, `INFRA`), PATH export, logging setup, `log` function.
    - Keep Phase 0 (self-heal proxy, lines 32-42).
    - Replace all phase code with `source` lines:
      ```
      source "$REPO_DIR/scripts/tool-setup.sh"
      source "$REPO_DIR/scripts/ollama-setup.sh"
      source "$REPO_DIR/scripts/docker-setup.sh"
      source "$REPO_DIR/scripts/deploy.sh"
      source "$REPO_DIR/scripts/systemd-setup.sh"
      source "$REPO_DIR/scripts/mesh-sync.sh"
      ```
    - Note: `set -euo pipefail` is set in install.sh before sourcing; each sourced module inherits it automatically and should NOT set it again.
    - Preserve the log calls between phases (`log "=== Phase 0a: ... ==="` etc.) inside each module.
    - Keep the final `log "Deployment completed successfully"` line (449-451).
    - Do NOT change env var names or the PATH export line.
  Parallelization: Wave 2 | Blocked by: Todo 4 | Blocks: 5, 6, 7, 8 (these are co-required, done together)
  References: install.sh:1-28,32-42,449-451
  Acceptance criteria (agent-executable): `bash -n install.sh` exits 0; `grep -c '^source' install.sh` == 6; `grep -v '^source' install.sh | grep -v '^#' | grep -v '^$' | wc -l` is ≤ 30 lines (thin orchestrator).
  QA scenarios:
    - Happy: install.sh is <30 executable lines (excluding comments/blanks), sources all 6 modules, and `bash -n` passes.
    - Failure: install.sh still contains phase logic, missing source lines, or syntax error.
    Evidence: `.omo/evidence/task-5-fix-install-sh-refactor.log`
  Commit: (included in Todo 4 commit)

- [ ] 6. Add post-copy verification to deploy_pure() and deploy_repo()
  What to do / Must NOT do:
    - In `scripts/deploy.sh`, after `cp -rf "$src/." "$dst/"` in `deploy_pure()`, add: verify that a representative file exists at destination (e.g., `[ -f "$dst/docker-compose.yml" ] || log "WARN: no docker-compose.yml in $dst"`).
    - In `deploy_repo()`, after `cp -rf "$src/." "$target/"`, add a similar check for the destination.
    - Use `|| log "WARN: ..."` so a missing file is non-fatal (best-effort deployment).
    - For `deploy_repo()`, the representative file depends on the component: check for `docker-compose.yml` or `package.json` (for 02-ai-llm-infra-sync).
    - Do NOT change the `cp -rf` behavior or add `set -e`-breaking constructs.
  Parallelization: Wave 3 | Blocked by: Todo 4 | Blocks: None
  References: scripts/deploy.sh (deploy_pure at ≈line 336, deploy_repo at ≈line 368)
  Acceptance criteria (agent-executable): `grep -q 'docker-compose.yml' scripts/deploy.sh` exits 0; `grep -q 'WARN.*no.*docker-compose.yml' scripts/deploy.sh` exits 0.
  QA scenarios:
    - Happy: `bash -n scripts/deploy.sh` passes. A dry-run test with an empty source template produces the warning.
    - Failure: `bash -n` fails, or the verify pattern is missing.
    Evidence: `.omo/evidence/task-6-fix-install-sh-refactor.log`
  Commit: Y | feat(deploy): add post-copy verification for silent failure detection

- [ ] 7. Fix mesh sync command chain in scripts/mesh-sync.sh
  What to do / Must NOT do:
    - Change `cd "$SYNC_DIR" && bun install >/dev/null 2>&1; bun sync` to `cd "$SYNC_DIR" && bun install >/dev/null 2>&1 && bun sync`.
    - The difference: `&&` on the second chain means `bun sync` only runs if `bun install` succeeds.
    - Do NOT change the `|| log "WARN: ..."` fallback.
  Parallelization: Wave 3 | Blocked by: Todo 4 | Blocks: None
  References: install.sh:440 (will be scripts/mesh-sync.sh after split)
  Acceptance criteria (agent-executable): `grep -c '&& bun sync' scripts/mesh-sync.sh` == 1; `grep -c '; bun sync' scripts/mesh-sync.sh` == 0.
  QA scenarios:
    - Happy: Command chain uses `&&` throughout.
    - Failure: Semicolon `;` still present before `bun sync`.
    Evidence: `.omo/evidence/task-7-fix-install-sh-refactor.log`
  Commit: Y | fix(mesh-sync): chain bun sync behind bun install with &&

- [ ] 8. DRY Ollama API key parser and guard git config + sudoers
  What to do / Must NOT do:
    - **Ollama DRY**: Extract one `read_api_key_file()` function that returns an array of keys from `$OLLAMA_API_KEY_FILE` (strips whitespace, skips `#` comments, handles empty lines). Replace the three call sites in `scripts/ollama-setup.sh` (`ensure_ollama_api_key`, `ensure_ollama_api_keys`, `ollama-keys`) with calls to this shared function.
    - **Git config guard**: Wrap `git config --global user.email` and `user.name` in an `if ! git config --global user.email >/dev/null 2>&1; then ... fi` check.
    - **Sudoers guard**: Before `sudo install` for the sudoers file, compute SHA256 of source; if destination exists with same hash, skip.
    - Do NOT change the behavior of the key-loading logic itself — only consolidate the parsing.
  Parallelization: Wave 3 | Blocked by: Todo 4 | Blocks: None
  References: install.sh:183-234 (three duplicates), install.sh:302-303 (git config), install.sh:417 (sudoers install)
  Acceptance criteria (agent-executable): `grep -c 'read_api_key_file' scripts/ollama-setup.sh` == 3 (called from three places) and `grep -c 'while.*read.*OLLAMA_API_KEY_FILE' scripts/ollama-setup.sh` == 0 (no raw loops); `grep -c 'if.*git config.*global.*user.email' scripts/deploy.sh` == 1; `grep -c 'sha256sum\|sha256' scripts/systemd-setup.sh` == 1.
  QA scenarios:
    - Happy: All three key-loading paths work identically via the shared function. Git config is skipped when already set. Sudoers install is skipped when content matches.
    - Failure: A raw loop over OLLAMA_API_KEY_FILE still exists, or git config always runs, or sudoers always overwrites.
    Evidence: `.omo/evidence/task-8-fix-install-sh-refactor.log`
  Commit: Y | refactor(ollama): DRY API key parser; guard git config and sudoers install

- [ ] 9. Create scripts/smoke-test.sh
  What to do / Must NOT do:
    - Create `scripts/smoke-test.sh` with `#!/bin/bash` and `set -euo pipefail`.
    - Check that each runtime pure-infra dir exists: `~/dev/01-core-infra/{portainer,plex,qbittorrent,cockpit}/docker-compose.yml`.
    - Check that each network runtime dir exists: `~/dev/04-network-{traefik,pihole,wireguard}/docker-compose.yml`.
    - Check that manifest repos exist: `~/dev/02-ai-llm-infra-sync/.git`, `~/dev/06-apps-thuis-v4/.git`, `~/dev/06-apps-thuis-v5/.git`, `~/dev/02-ai-freellmapi/.git`.
    - Check that cron file has no placeholders at destination: `/etc/cron.d/01-core-infra` should have no `__HOME__`/`__USER__`/`__CORE_INFRA__`.
    - Check that systemd helpers exist: `/usr/local/bin/app-deploy-systemd` and `/usr/local/bin/app-install-cron` are executable.
    - Exit 0 if all checks pass, exit 1 with a list of failures otherwise.
    - Use `[ -f "$path" ]` checks; write one `FAIL: $reason` per failure to stdout.
    - Do NOT start Docker containers or check service health (that's healthcheck.sh's job).
    - For root-owned paths (/etc/cron.d/, /usr/local/bin/): check via `sudo test -f` if sudo is available without password; otherwise skip those checks with a "SKIP (requires root)" note.
  Parallelization: Wave 4 | Blocked by: Todos 4, 5, 6, 7, 8 | Blocks: 12
  References: (new file) — no existing reference.
  Acceptance criteria (agent-executable): `bash -n scripts/smoke-test.sh` exits 0; `bash scripts/smoke-test.sh` exits 0 when all runtime dirs exist.
  QA scenarios:
    - Happy: All runtime dirs present → exits 0 with "ALL CHECKS PASSED".
    - Failure: A runtime dir removed → exits 1 with specific "FAIL:" lines.
    Evidence: `.omo/evidence/task-9-fix-install-sh-refactor.log`
  Commit: Y | feat(scripts): add smoke-test.sh for post-deploy verification

- [ ] 10. Update AGENTS.md with new script structure
  What to do / Must NOT do:
    - Read the current AGENTS.md first (it was updated in the previous session).
    - Add a `## Scripts` section describing each file: `install.sh` (orchestrator), `scripts/tool-setup.sh`, `scripts/ollama-setup.sh`, `scripts/docker-setup.sh`, `scripts/deploy.sh`, `scripts/systemd-setup.sh`, `scripts/mesh-sync.sh`, `scripts/smoke-test.sh`.
    - Update the `install.sh — What It Does` section to mention that the phases are now in `scripts/*.sh` files, sourced by install.sh.
    - Add `scripts/smoke-test.sh` to the relevant sections.
    - Do NOT rewrite the entire AGENTS.md — only update/add sections that changed due to the refactor.
  Parallelization: Wave 4 | Blocked by: Todos 4, 5, 6, 7, 8 | Blocks: 12
  References: AGENTS.md, scripts/*.sh (after split)
  Acceptance criteria (agent-executable): `grep -q 'scripts/tool-setup.sh' AGENTS.md` exits 0; `grep -q 'scripts/smoke-test.sh' AGENTS.md` exits 0; `grep -c 'scripts/' AGENTS.md` >= 7 (all scripts mentioned).
  QA scenarios:
    - Happy: AGENTS.md describes all 7 scripts (install.sh + 6 modules + smoke-test).
    - Failure: A script file exists but is not mentioned.
    Evidence: `.omo/evidence/task-10-fix-install-sh-refactor.log`
  Commit: Y | docs(AGENTS.md): update with new scripts/ module structure

- [ ] 11. Run install.sh end-to-end
  What to do / Must NOT do:
    - Run `cd ~/dev/01-core-infra && ./install.sh`.
    - It must complete without errors (exit 0).
    - All runtime dirs must be populated after the run.
    - Do NOT modify any files during this step — pure execution.
  Parallelization: Wave 4 | Blocked by: Todos 1-10 | Blocks: 12
  References: install.sh (after split)
  Acceptance criteria (agent-executable): `./install.sh` exits 0. Last log line is "Deployment completed successfully".
  QA scenarios:
    - Happy: install.sh exits 0, log shows all phases OK.
    - Failure: install.sh exits non-zero or log shows errors.
    Evidence: `.omo/evidence/task-11-fix-install-sh-refactor.log`
  Commit: N (verification step)

- [ ] 12. Run smoke-test.sh + healthcheck.sh to verify everything works
  What to do / Must NOT do:
    - Run `bash ~/dev/01-core-infra/scripts/smoke-test.sh` — must exit 0.
    - Run `bash ~/dev/01-core-infra/healthcheck.sh` — must exit 0 (all Docker containers and systemd units up).
    - Do NOT modify any files.
  Parallelization: Wave 4 | Blocked by: Todo 11 | Blocks: None
  References: scripts/smoke-test.sh, healthcheck.sh
  Acceptance criteria (agent-executable): `bash scripts/smoke-test.sh` exits 0; `bash healthcheck.sh` exits 0.
  QA scenarios:
    - Happy: Both scripts exit 0.
    - Failure: smoke-test.sh finds missing dirs or healthcheck.sh finds down services.
    Evidence: `.omo/evidence/task-12-fix-install-sh-refactor.log`
  Commit: N (verification step)

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [ ] F1. Plan compliance audit
- [ ] F2. Code quality review
- [ ] F3. Real manual QA
- [ ] F4. Scope fidelity

## Commit strategy
1. `fix(husky): set TEMPLATE variable and fix quoting in pre-commit hook`
2. `fix(cron): replace hardcoded paths with placeholders and remove bell characters`
3. `fix(systemd): stop sed -i on source template; write to temp file instead`
4. `refactor(scripts): split install.sh into 6 focused modules under scripts/`
   (includes the thin orchestrator rewrite + all extracted code as-is)
5. `feat(deploy): add post-copy verification for silent failure detection`
6. `fix(mesh-sync): chain bun sync behind bun install with &&`
7. `refactor(ollama): DRY API key parser; guard git config and sudoers install`
8. `feat(scripts): add smoke-test.sh for post-deploy verification`
9. `docs(AGENTS.md): update with new scripts/ module structure`

Commits 5, 6, 7 can be squashed into a single `fix: install.sh bug fixes` if preferred.

## Success criteria
- [ ] `bash -n` passes on all `.sh` files (install.sh, scripts/*.sh, backup.sh, healthcheck.sh, .husky/pre-commit, templates/systemd/*).
- [ ] `./install.sh` runs to completion with exit 0.
- [ ] `scripts/smoke-test.sh` exits 0 (all runtime dirs, compose files, manifest repos, cron, systemd helpers verified).
- [ ] `./healthcheck.sh` exits 0 (all Docker containers and systemd units healthy).
- [ ] Pre-commit hook passes with any cron template that has placeholders.
- [ ] Cron template has no hardcoded paths — only `__HOME__`, `__USER__`, `__CORE_INFRA__`.
- [ ] `app-install-cron` does NOT mutate the source cron template file.
- [ ] `deploy_pure()`/`deploy_repo()` warn if destination is missing expected files.
- [ ] `bun sync` in mesh-sync module only runs if `bun install` succeeds.
- [ ] Ollama key parser has exactly 1 implementation of the file-reading loop, used by 3 call sites.
- [ ] `git config --global` is skipped when user.email is already set.
- [ ] Sudoers install is skipped when destination content matches source.
