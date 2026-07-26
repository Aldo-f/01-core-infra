# Fix: GitHub Actions workflow fails

## Status
status: in-progress

## Problems
1. Root `npm ci` step in workflow fails — **FIXED**
2. `docs-theme` submodule points to `git@github.com:Aldo-f/docusaurus-theme.git` which **does not exist** (404) — submodule clone fails in CI

## Fix

### Problem 1 (done)
Remove the root `npm ci` step — `.github/workflows/deploy-docs.yml` fixed.

### Problem 2 (current)
The `docs-theme` submodule remote doesn't exist on GitHub. Remove the submodule, keep `docs-theme/` as a regular directory. The `docs/package.json` already uses `"file:../docs-theme"` — a local path reference that works without submodules.

## Expected outcome
- GitHub Action runs to completion
- Docusaurus build succeeds
- Docs deployed to https://aldo-f.github.io/01-core-infra/ returns 200

## Todos
- [x] 1. Remove "Install dependencies (root)" step from `.github/workflows/deploy-docs.yml`
- [ ] 2. Remove docs-theme submodule, keep files as regular directory
- [ ] F1. Commit & push, verify workflow + docs URL return 200
