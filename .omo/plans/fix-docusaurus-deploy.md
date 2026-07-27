# Fix: Docusaurus GitHub Actions deployment failure

## Status
status: awaiting-implementation

## Problems
1. GitHub Actions workflow fails at 'Setup Node.js' step due to Node.js version deprecation warning.
2. `npm ci` in the `docs` directory fails because the lock file is not found.
3. Documentation site is inaccessible (404 error at https://aldo-f.github.io/01-core-infra/).

## Fixes
1. **Update Node.js version**: In `.github/workflows/deploy-docs.yml`, change `node-version` from `20.x` to `24` (or the latest stable version) to align with the GitHub Actions runner environment and potentially resolve deprecation issues.
2. **Address lock file issue**: Investigate why `npm ci` cannot find `package-lock.json` in the `docs/` directory. This might involve ensuring the `checkout` action correctly fetches the `docs` directory or its contents.

## Expected outcome
- GitHub Actions workflow runs to completion successfully.
- Docusaurus site builds correctly.
- Documentation becomes accessible at https://aldo-f.github.io/01-core-infra/ (returns 200).

## Todos
- [ ] 1. Update `node-version` in `.github/workflows/deploy-docs.yml` to `20.x` (or latest).
- [ ] 2. Investigate and fix `npm ci` failure regarding missing lock file in `docs/`.
- [ ] 3. Commit and push the workflow and `docs` directory changes.
- [ ] F1. Verify the GitHub Actions workflow completes successfully.
- [ ] F2. Check `https://aldo-f.github.io/01-core-infra/` returns a 200 status code.