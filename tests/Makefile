# tests/Makefile — Run Docker-based Ansible tests
# See tests/test-deploy.sh for the actual Docker build+run logic.

SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

.PHONY: test-pi5 test-pi3 test-all clean

test-pi5:
	@echo "═══ Running test: pi5 ═══"
	@tests/test-deploy.sh --pi5

test-pi3:
	@echo "═══ Running test: pi3 ═══"
	@tests/test-deploy.sh --pi3

test-all:
	@echo "══════════════════════════════════════════════════"
	@echo "  Running ALL tests (pi5 → pi3)"
	@echo "══════════════════════════════════════════════════"
	$(MAKE) test-pi5
	@echo ""
	$(MAKE) test-pi3
	@echo ""
	@echo "═══ All tests completed ═══"

clean:
	@echo "Removing test output logs..."
	@rm -fv tests/test-output-*.log
	@echo "Done."
