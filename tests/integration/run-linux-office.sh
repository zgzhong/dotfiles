#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DOTFILES_SRC="${DOTFILES_SRC:-$REPO_ROOT}"
IMAGE_TAG="${IMAGE_TAG:-dotfiles-it:linux-office}"
KEEP_CONTAINER="${KEEP_CONTAINER:-0}"
CONTAINER_NAME="dotfiles-it-linux-office-$(date +%s)"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not found" >&2
  exit 1
fi

echo "[integration] Building image: ${IMAGE_TAG}"
docker build \
  -f "${REPO_ROOT}/tests/integration/linux-office/Dockerfile" \
  -t "${IMAGE_TAG}" \
  "${REPO_ROOT}"

echo "[integration] Running container: ${CONTAINER_NAME}"
run_args=(
  --name "${CONTAINER_NAME}"
  -e WORKSPACE=/workspace
  -v "${DOTFILES_SRC}:/workspace:ro"
  "${IMAGE_TAG}"
  bash /workspace/tests/integration/linux-office/run-e2e.sh
)

if [[ "$KEEP_CONTAINER" != "1" ]]; then
  run_args=(--rm "${run_args[@]}")
fi

if docker run "${run_args[@]}"; then
  echo "[integration] Linux office integration test passed"
else
  echo "[integration] Linux office integration test failed" >&2
  if [[ "$KEEP_CONTAINER" == "1" ]]; then
    echo "[integration] Container kept for inspection: ${CONTAINER_NAME}" >&2
  fi
  exit 1
fi
