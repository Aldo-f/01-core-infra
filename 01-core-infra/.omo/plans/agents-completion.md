# AGENTS.md — reconciliation completion + one pending fix

Status: the AGENTS.md reconciliation (see prior session) is DONE and written to
`AGENTS.md`. This plan captures the ONE outstanding edit discovered during
self-review.

## Pending edit

- File: `AGENTS.md`
- Location: line 55, section "### Components per group / 06-apps"
- Change: fix typo `06-apps-neo4ty-brutalist-home` → `06-apps-neo-brutalist-home`
- Reason: the component name is `06-apps-neo-brutalist-home` (matches role
  `neo-brutalist-home`, template dir `templates/infra/06-apps-neo-brutalist-home`);
  the "neo4ty" variant is a misspelling introduced by me.

## Done (verified, no further work)

Group taxonomy, install.sh/deploy.sh flow, container_services wiring (only
01-core + 07-security auto-deployed; 05-media templates not yet wired),
Vault/master.key guidance, role order, CI checks — all reconciled to the
current working tree.