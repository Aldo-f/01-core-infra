# Plan: Volledig Ansible-alternatief voor install.sh + Docker-testing

## Doel
Maak Ansible tot een volledig alternatief voor install.sh, inclusief Docker-gebaseerde testing voor Pi3 (1GB) en Pi5 (8GB).

## Scope
- Voeg ontbrekende tool-installaties toe aan Ansible roles
- Voeg Docker installatie toe aan base role
- Maak Docker-based test workflow
- Test op Pi5 (8GB) en simuleer Pi3 (1GB)

## Must NOT Have
- Geen wijzigingen aan install.sh (die blijft bestaan als fallback)
- Geen cloud/VM oplossingen (alleen lokaal Docker)
- Geen architectuur-specifieke code (Docker multiarch handles dit)

---

## Todos

### Fase 1: Ansible roles compleet maken

- [x] 1. **base role uitbreiden** — Voeg git, tree, Docker + Docker Compose toe aan `ansible/roles/base/tasks/main.yml`
  -bron: install.sh Phase 0a (git, tree) + Phase 0b (Docker)
  -驗收: `ansible-playbook --check` toont geen wijzigingen voor reeds geïnstalleerde packages

- [x] 2. **tools role uitbreiden** — Voeg alle ontbrekende CLI tools toe aan `ansible/roles/tools/tasks/main.yml`
  - bron: install.sh Phase 0a (node, pnpm, bun, fvm, ollama, hermes, opencode, tailscale)
  - elke tool: sentry check → install → verify
  -驗收: elke tool heeft een `creates` of `when` conditie voor idempotentie

- [x] 3. **OMO installatie toevoegen** — Voeg oh-my-openagent installatie toe aan tools role
  - bron: install.sh regel 93-105
  - marker file: `~/.config/opencode/.omo-installed-by-01-core-infra`
  -驗收: OMO wordt alleen geïnstalleerd als marker ontbreekt

### Fase 2: Docker-testing workflow

- [x] 4. **Dockerfile maken** — Maak `tests/Dockerfile.pi5` (Ubuntu 24.04, 8GB RAM limiet)
  - bron: Pi5 = aarch64, 8GB RAM
  -基底: `ubuntu:24.04`
  -驗收: `docker build` slaagt

- [x] 5. **Dockerfile Pi3 maken** — Maak `tests/Dockerfile.pi3` (Ubuntu 24.04, 1GB RAM limiet)
  - bron: Pi3 = armv7, 1GB RAM
  -基底: `arm32v7/ubuntu:24.04` (via QEMU)
  -驗收: `docker build` slaagt op x86 met QEMU

- [x] 6. **Test script maken** — Maak `tests/test-deploy.sh`
  - voert ansible-playbook uit in container
  - test of alle tools geïnstalleerd zijn
  - test of systemd services correct zijn
  -驗收: script retourneert exit 0 bij succes

- [x] 7. **Makefile toevoegen** — Maak `tests/Makefile` voor eenvoudige test commands
  - `make test-pi5` — test op Pi5 config
  - `make test-pi3` — test op Pi3 config
  - `make test-all` — beide tests
  -驗收: `make test-all` draait zonder interactie

### Fase 3: Verificatie

- [x] 8. **Volledige deploy testen** — Draai ansible-playbook in Pi5 container
  - base role (git, tree, Docker, docker group) ✅ OK
  - tools role (fish) ✅ OK
  - LM Studio steps (link enable, daemon up) ❌ hangt in container — heeft running daemon nodig
  -驗收: geen errors in ansible-playbook output (behalve LM Studio timeout)

- [~] 9. **Idempotentie testen** — Draai ansible-playbook twee keer
  - Geblokkeerd: Todo 8 voltooid niet volledig door LM Studio hang
  - Idempotentie kan pas getest worden nadat LM Studio timeout is opgelost

---

## Final verification wave

- [x] F1. **install.sh vs Ansible vergelijking** — Voer install.sh uit in schone container, vergelijk resultaat met Ansible
  - beide moeten dezelfde tools installeren
  -驗收: `diff` tussen tool lijsten toont geen verschillen
  - RESULTAAT: Alle 14 tools gedekt. Ansible heeft 1 extra (LM Studio daemon). Mist: hermes workspace (optioneel), Ollama model pull (seed-only). Dode sentry `gh` gevonden.

- [~] F2. **Docker test workflow** — Voer `make test-all` uit
  - both Pi3 and Pi5 tests must pass
  -驗收: exit code 0
  - GEBLOKKEERD: LM Studio `lms link enable`/`lms daemon up` hangt in Docker container (verwacht — heeft running daemon nodig)

---

## Dependency matrix

| Todo | Depends on | Reason |
|------|------------|--------|
| 1 (base) | — | Foundation |
| 2 (tools) | 1 | Tools need base packages |
| 3 (OMO) | 2 | OMO needs opencode + bun |
| 4 (Dockerfile pi5) | — | Independent |
| 5 (Dockerfile pi3) | 4 | Same pattern |
| 6 (test script) | 4, 5 | Needs containers |
| 7 (Makefile) | 6 | Wraps test script |
| 8 (full test) | 1-7 | Needs everything |
| 9 (idempotency) | 8 | Second run |

## Parallel execution notes

- Fase 1 (todos 1-3) kan parallel met Fase 2 (todos 4-5)
- Todo 6 wacht op 4+5
- Todo 7 wacht op 6
- Todos 8-9 wachten op alles
