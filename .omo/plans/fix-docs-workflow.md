# Fix: GitHub Actions workflow fails at root npm ci

## Status
status: awaiting-implementation

## Problem
`.github/workflows/deploy-docs.yml` step "Install dependencies (root)" runs `npm ci` at repo root, but there is no `package.json` there. The step fails, the whole workflow dies in ~9s, and no docs get deployed to GitHub Pages.

## Fix
Remove the root `npm ci` step entirely — only the docs directory has a `package.json`.

## Expected outcome
- Workflow runs to completion
- Docusaurus build succeeds
- Docs are deployed to https://aldo-f.github.io/01-core-infra/

## Todo
- [x] 1. Remove "Install dependencies (root)" step from `.github/workflows/deploy-docs.yml`
- [ ] F1. Push to main, verify workflow runs successfully, check https://aldo-f.github.io/01-core-infra/ returns 200
