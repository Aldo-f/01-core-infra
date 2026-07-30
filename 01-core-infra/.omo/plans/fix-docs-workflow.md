# Fix: GitHub Actions workflow fails

## Status
status: in-progress

## Problems
1. Root `npm ci` step in workflow fails — **FIXED**
2. `docs-theme` submodule points to `git@github.com:Aldo-f/docusaurus-theme.git` which **does not exist** (404) — submodule clone fails in CI — **FIXED**
3. `Setup Node.js` action fails due to missing dependencies lock file at the repository root when `cache: 'npm'` is used — **CURRENT**

## Fix

### Problem 1 (done)
Remove the root `npm ci` step — `.github/workflows/deploy-docs.yml` fixed.

### Problem 2 (done)
Remove the submodule, keep `docs-theme/` as a regular directory.

### Problem 3 (current)
Configure `cache-dependency-path: docs/package-lock.json` in the Setup Node.js step of `.github/workflows/deploy-docs.yml`.

## Expected outcome
- GitHub Action runs to completion
- Docusaurus build succeeds
- Docs deployed to https://aldo-f.github.io/01-core-infra/ returns 200

## Todos
- [x] 1. Remove "Install dependencies (root)" step from `.github/workflows/deploy-docs.yml`
- [x] 2. Remove docs-theme submodule, keep files as regular directory
- [ ] 3. Fix Setup Node.js caching in `.github/workflows/deploy-docs.yml`
- [ ] F1. Commit & push, verify workflow succeeds and docs URL returns 200
