#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DOTFILES_SRC="${DOTFILES_SRC:-$REPO_ROOT}"
IMAGE_TAG="${IMAGE_TAG:-dotfiles-it:cold-boot}"
CONTAINER_NAME="${CONTAINER_NAME:-dotfiles-it-cold-boot}"
STATUS_FILE="${STATUS_FILE:-/tmp/dotfiles-cold-boot.exitcode}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not found" >&2
  exit 1
fi

echo "[cold-boot] Building image: ${IMAGE_TAG}"
build_args=()
if [[ -n "${HTTP_PROXY:-}" ]]; then
  build_args+=(--build-arg "HTTP_PROXY=${HTTP_PROXY}")
fi
if [[ -n "${HTTPS_PROXY:-}" ]]; then
  build_args+=(--build-arg "HTTPS_PROXY=${HTTPS_PROXY}")
fi

docker build \
  "${build_args[@]+"${build_args[@]}"}" \
  -f "${REPO_ROOT}/tests/integration/cold-boot/Dockerfile" \
  -t "${IMAGE_TAG}" \
  "${REPO_ROOT}"

if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "[cold-boot] Removing existing container: ${CONTAINER_NAME}"
  docker rm -f "${CONTAINER_NAME}" >/dev/null
fi

echo "[cold-boot] Running container: ${CONTAINER_NAME}"
run_args=(
  -d
  --name "${CONTAINER_NAME}"
  -e WORKSPACE=/workspace
  -v "${DOTFILES_SRC}:/workspace:ro"
  "${IMAGE_TAG}"
  tail -f /dev/null
)

docker run "${run_args[@]}" >/dev/null

set +e
docker exec \
  -e WORKSPACE=/workspace \
  "${CONTAINER_NAME}" \
  bash -lc '
    status_file="$1"
    shift

    rm -f "$status_file"
    "$@"
    status=$?
    printf "%s\n" "$status" >"$status_file"
    exit 0
  ' -- "${STATUS_FILE}" bash /workspace/tests/integration/cold-boot/run-e2e.sh
exec_status=$?
set -e

test_status=""
if docker exec "${CONTAINER_NAME}" cat "${STATUS_FILE}" >/tmp/dotfiles-cold-boot.status 2>/dev/null; then
  test_status="$(tr -d "[:space:]" </tmp/dotfiles-cold-boot.status)"
fi
rm -f /tmp/dotfiles-cold-boot.status

if [[ -z "${test_status}" ]]; then
  echo "[cold-boot] Failed to read test status from container; docker exec exit code: ${exec_status}" >&2
  echo "[cold-boot] Container kept running for inspection: ${CONTAINER_NAME}" >&2
  exit 1
fi

if [[ "${test_status}" == "0" ]]; then
  echo "[cold-boot] Cold-boot integration test passed"
  echo "[cold-boot] Container kept running for inspection: ${CONTAINER_NAME}"
else
  echo "[cold-boot] Cold-boot integration test failed" >&2
  echo "[cold-boot] Container kept running for inspection: ${CONTAINER_NAME}" >&2
fi

exit "${test_status}"
