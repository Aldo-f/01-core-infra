#!/usr/bin/env bash
# tests/test-deploy.sh — Run Ansible playbook in Docker container
# Usage: tests/test-deploy.sh --pi5|--pi3
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VARIANT=""
case "${1:-}" in
  --pi5) VARIANT="pi5" ;;
  --pi3) VARIANT="pi3" ;;
  *)
    echo "Usage: $0 --pi5|--pi3" >&2
    exit 1
    ;;
esac

IMAGE="test-${VARIANT}"
DOCKERFILE="${SCRIPT_DIR}/Dockerfile.${VARIANT}"
LOG="${SCRIPT_DIR}/test-output-${VARIANT}.log"

case "${VARIANT}" in
  pi5) MEMORY="8g" ;;
  pi3) MEMORY="1g" ;;
esac

# ── Build ──────────────────────────────────────────────────────────────
echo "[test-deploy] Building Docker image: ${IMAGE}"
IMAGE_ID="$(docker build -q -t "${IMAGE}" -f "${DOCKERFILE}" "${REPO_ROOT}")"
echo "[test-deploy] Image built: ${IMAGE_ID}"

# ── Run ────────────────────────────────────────────────────────────────
echo "[test-deploy] Running Ansible playbook in container (memory=${MEMORY})..."
set +e
docker run --rm \
  --memory "${MEMORY}" \
  -v "${REPO_ROOT}:__CORE_INFRA__" \
  "${IMAGE}" \
  bash -c "cd __CORE_INFRA__/ansible && ansible-playbook -e container_test=true playbooks/site.yml" \
  > "${LOG}" 2>&1

EXIT_CODE=$?
set -e

echo "[test-deploy] Ansible exit code: ${EXIT_CODE}"
echo "[test-deploy] Full output logged to: ${LOG}"
echo "──────────────────────────────────────────────────────────────────"
cat "${LOG}"
echo "──────────────────────────────────────────────────────────────────"

if [ "${EXIT_CODE}" -eq 0 ]; then
  echo "[test-deploy] SUCCESS"
  exit 0
else
  echo "[test-deploy] FAILURE (exit ${EXIT_CODE})"
  exit 1
fi
