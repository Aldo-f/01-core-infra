---
slug: curl-bootstrap-install
status: drafting
intent: clear
review_required: false
plan_path: .omo/plans/curl-bootstrap-install.md
plan_sha256: null
review_round_id: null
pending-action: present approval brief
review:
  momus:
    status: pending
    workspace_root: null
    runtime_home: null
    target: .omo/plans/curl-bootstrap-install.md
    round_id: null
    plan_sha256: null
    launch_id: null
    session: null
    result: null
  independent:
    status: pending
    workspace_root: null
    runtime_home: null
    target: .omo/plans/curl-bootstrap-install.md
    round_id: null
    plan_sha256: null
    launch_id: null
    session: null
    result: null
approach: Rewrite install.sh as a bootstrap that clones the repo if missing then execs the deploy; create scripts/deploy.sh with the real install logic; tag v0.0.1; update AGENTS.md; update backup.sh and healthcheck.sh to reference deploy.sh path.
---

# Draft: curl-bootstrap-install

## Components (topology ledger)
<!-- id | outcome (one line) | status: active|deferred | evidence path -->
1 | `install.sh` — rewrite as bootstrap (clone + exec) | active | install.sh (current: 451 lines, expects pre-cloned repo)
2 | `scripts/deploy.sh` — create with current install.sh logic (or reference existing scripts/ modules if already split) | active | install.sh:44-451 (all phase logic)
3 | `backup.sh` — verify BASH_SOURCE works inside cloned repo | active | backup.sh:6 (uses BASH_SOURCE[0])
4 | `healthcheck.sh` — same verification | active | healthcheck.sh:6
5 | Git tag `v0.0.1` — first release tag | active | no tags exist yet
6 | `AGENTS.md` — document bootstrap pattern | active | AGENTS.md:1-126
7 | Existing draft `fix-install-sh-refactor` — assess overlap | active | .omo/drafts/fix-install-sh-refactor.md

## Open assumptions (announced defaults)
<!-- assumption | adopted default | rationale | reversible? -->
Bootstrap architecture: install.sh detects missing repo, clones, execs deploy | install.sh checks for `templates/infra/` to decide if it's inside a cloned repo | Simplest single-script curl|bash pattern used by rustup/nvm/oh-my-zsh | Yes
Version tag for first release | v0.0.1 | Lowest valid semver for a first release | Yes (tags can be added, never removed from remote)
Where deploy logic lives | `scripts/deploy.sh` (repo-root scripts/ dir) | Aligns with existing plan to have modules under scripts/ | Yes
Default clone version in bootstrap | `VERSION="${VERSION:-v0.0.1}"` with env var override | Pins to tag the URL was fetched from, allows override | Yes
Fate of existing fix-install-sh-refactor plan | Deferred — bootstrap is simpler; module split can follow as separate work | The curl|bash bootstrap doesn't require module split; install.sh can stay monolithic inside deploy.sh | Yes

## Key Design Decision

The critical fork: **how does install.sh decide "I'm running via curl | bash vs. I'm running from the cloned repo?"**

Default: Check if `templates/infra/` exists relative to the script. If missing → clone repo at $VERSION → exec from cloned path. If present → source/run deploy logic.

This is self-healing: even a corrupted or partial clone gets fixed.

## Open questions
None — all forks resolved by exploration + adopted defaults.
