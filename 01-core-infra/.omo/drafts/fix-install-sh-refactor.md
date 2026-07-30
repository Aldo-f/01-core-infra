---
slug: fix-install-sh-refactor
status: drafting
intent: clear
review_required: true
plan_path: .omo/plans/fix-install-sh-refactor.md
plan_sha256: null
review_round_id: null
pending-action: write and review .omo/plans/fix-install-sh-refactor.md
review:
  momus:
    status: pending
    workspace_root: null
    runtime_home: null
    target: .omo/plans/fix-install-sh-refactor.md
    round_id: null
    plan_sha256: null
    launch_id: null
    session: null
    result: null
  independent:
    status: pending
    workspace_root: null
    runtime_home: null
    target: .omo/plans/fix-install-sh-refactor.md
    round_id: null
    plan_sha256: null
    launch_id: null
    session: null
    result: null
approach: fix 8 bugs, split install.sh into scripts/ modules, add smoke-test.sh, update AGENTS.md, run install.sh to verify
---

# Draft: fix-install-sh-refactor

## Components (topology ledger)
<!-- Lock the SHAPE before depth. One row per top-level component that can succeed or fail independently. -->
<!-- id | outcome (one line) | status: active|deferred | evidence path -->
1 | `.husky/pre-commit` — fix broken $TEMPLATE variable + quoting | active | .husky/pre-commit:9-28
2 | `templates/cron/01-core-infra.cron` — replace hardcoded paths with placeholders, remove bell chars | active | templates/cron/01-core-infra.cron:1-11
3 | `templates/systemd/app-install-cron` — stop mutating source of truth (temp file instead of sed -i) | active | templates/systemd/app-install-cron:12-20
4 | `install.sh` — add post-copy verification in deploy_pure()/deploy_repo() | active | install.sh:330-338,341-370
5 | `install.sh` — fix mesh sync: bun sync must not run if bun install fails | active | install.sh:440
6 | `install.sh` — DRY the Ollama API key file parser (3 identical loops into 1 function) | active | install.sh:183-234
7 | `install.sh` — guard git config --global behind existence check | active | install.sh:302-303
8 | `install.sh` — guard sudoers install behind content-hash check | active | install.sh:417
9 | `AGENTS.md` — update to reflect fixed scripts | active | AGENTS.md
10 | install.sh module split — extract tool setup, ollama, docker, deploy, systemd, mesh-sync into scripts/ | active | install.sh:44-451
11 | Smoke-test script — verify runtime dirs, compose files, manifest repos, cron destination, systemd helpers | active | (new file)
12 | Standardize docker-compose patterns across 11 components | defer | templates/infra/*/docker-compose.yml

## Open assumptions (announced defaults)
<!-- Record any default you adopt instead of asking, so the user can veto it at the gate. -->
<!-- assumption | adopted default | rationale | reversible? -->
install.sh module split: one file per logical phase, sourced by thin orchestrator | `scripts/`, not a subpackage or Makefile | Keeps bash-native pattern, avoids over-engineering | Yes (easy to re-merge)
Module file names: `tool-setup.sh`, `ollama-setup.sh`, `docker-setup.sh`, `deploy.sh`, `systemd-setup.sh`, `mesh-sync.sh` | Named after what they do | Clear mapping to install.sh phases | Yes
Docker-compose standardization deferred | Don't touch docker-compose files | The user asked for infra refactor, not component config; installing.sh refactoring is the scope | N/A

## Findings (cited - path:lines)
Pre-commit hook: `$TEMPLATE` never assigned (.husky/pre-commit:9,14,19,25), `\"$TEMPLATE"` quoting breaks, `set -u` would abort on unbound var.
Cron template: hardcoded `__CORE_INFRA__/` + `aldo` + stray bell `\x07` chars (templates/cron/01-core-infra.cron:8,11) — no `__HOME__`/`__USER__`/`__CORE_INFRA__` used.
app-install-cron: `sed -i` writes back to source template (templates/systemd/app-install-cron:18) — destructive.
deploy_pure/deploy_repo: `cp -rf` with zero verification (install.sh:336,368).
Mesh sync: `&& bun install ...; bun sync` — second command always runs (install.sh:440).
Ollama parser: 3 identical file-reading loops (install.sh:183-193, 196-214, 217-234) — extract to 1 function.
git config: runs `--global` every deploy (install.sh:302-303) — no guard.
sudoers: `sudo install` overwrites every run (install.sh:417) — no guard.
Scripts: `install.sh` is 451 lines doing 10+ unrelated things — good candidate for module split.
No smoke-test exists — deployment failures go undetected until healthcheck finds missing containers.

## Decisions (with rationale)
- Module split is scoped to `install.sh` only (not helper scripts like backup.sh/healthcheck.sh).
- Module files go in `scripts/` dir at repo root (not `templates/scripts/` — they are build-time infrastructure, not component templates).
- Docker-compose standardization is DEFERRED: changing 11 compose files for consistency is a separate initiative, not part of this install.sh refactor.
- No test harness beyond the smoke-test script: the repo has zero test infrastructure, and adding a framework is outside scope.
- AGENTS.md updated only for the sections affected by the refactored scripts.

## Scope IN
1. Fix .husky/pre-commit: set $TEMPLATE, fix quoting, add path to cron template.
2. Fix cron template: replace hardcoded paths with `__HOME__`, `__USER__`, `__CORE_INFRA__`; remove bell chars.
3. Fix app-install-cron: write to temp file → install, never sed -i on source.
4. Install.sh post-copy verification: check representative file exists after cp -rf.
5. Install.sh mesh sync: `&&` chain correctly.
6. DRY Ollama parser: extract one shared `read_api_key_file()` function.
7. Guard git config --global.
8. Guard sudoers install.
9. Module split: extract install.sh phases into `scripts/{tool-setup,ollama-setup,docker-setup,deploy,systemd-setup,mesh-sync}.sh`, install.sh becomes thin orchestrator.
10. Add `scripts/smoke-test.sh`: verify runtime dirs, compose files, manifest repos, cron, systemd helpers.
11. Update AGENTS.md for structural changes.
12. Run `./install.sh` at end to prove everything still works.

## Scope OUT (Must NOT have)
- Do NOT touch docker-compose.yml contents in any component.
- Do NOT add a test framework (no Jest, no bats, no pytest).
- Do NOT change runtime behavior of any deploy step — outputs must be byte-identical.
- Do NOT modify backup.sh, healthcheck.sh, or their crontab entries functionally (only placeholder migration).
- Do NOT modify templates/infra/repos.manifest.jsonc or its parsing.
- Do NOT rename the existing scripts or delete files not created by this plan.

## Open questions
None — all forks resolved by exploration + user's "Broader refactor" answer.

## Approval gate
status: awaiting-approval
<!-- The brief was presented on 2026-07-24. Waiting for explicit user approval before writing the plan. -->
<!-- recommended approach module split: scripts/{tool-setup,ollama-setup,docker-setup,deploy,systemd-setup,mesh-sync}.sh -->
