#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DOTFILES_SRC="${DOTFILES_SRC:-$REPO_ROOT}"
IMAGE_TAG="${IMAGE_TAG:-dotfiles-it:linux-office}"
CONTAINER_NAME="${CONTAINER_NAME:-dotfiles-it-linux-office}"
STATUS_FILE="${STATUS_FILE:-/tmp/dotfiles-e2e.exitcode}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not found" >&2
  exit 1
fi

echo "[integration] Building image: ${IMAGE_TAG}"
build_args=()
if [[ -n "${HTTP_PROXY:-}" ]]; then
  build_args+=(--build-arg "HTTP_PROXY=${HTTP_PROXY}")
fi
if [[ -n "${HTTPS_PROXY:-}" ]]; then
  build_args+=(--build-arg "HTTPS_PROXY=${HTTPS_PROXY}")
fi

docker build \
  "${build_args[@]+"${build_args[@]}"}" \
  -f "${REPO_ROOT}/tests/integration/linux-office/Dockerfile" \
  -t "${IMAGE_TAG}" \
  "${REPO_ROOT}"

if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "[integration] Removing existing container: ${CONTAINER_NAME}"
  docker rm -f "${CONTAINER_NAME}" >/dev/null
fi

echo "[integration] Running container: ${CONTAINER_NAME}"
run_args=(
  -d
  --name "${CONTAINER_NAME}"
  -e WORKSPACE=/workspace
  -v "${DOTFILES_SRC}:/workspace:ro"
  "${IMAGE_TAG}"
  # 让容器的 PID 1 持续存活，这样 e2e 跑完后容器仍可进入排查。
  tail -f /dev/null
)

docker run "${run_args[@]}" >/dev/null

set +e
# 在容器内执行完整的 Linux office e2e：应用 dotfiles、校验工具安装和渲染结果，
# 然后把退出码写入容器内的状态文件，供外层脚本读取。
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
  ' -- "${STATUS_FILE}" bash /workspace/tests/integration/linux-office/run-e2e.sh
exec_status=$?
set -e

test_status=""
# 通过 docker exec 在容器内读取状态文件，stdout 会被宿主机 shell
# 重定向到临时文件，因此这里不需要额外使用 docker cp。
if docker exec "${CONTAINER_NAME}" cat "${STATUS_FILE}" >/tmp/dotfiles-linux-office.status 2>/dev/null; then
  test_status="$(tr -d "[:space:]" </tmp/dotfiles-linux-office.status)"
fi
rm -f /tmp/dotfiles-linux-office.status

if [[ -z "${test_status}" ]]; then
  echo "[integration] Failed to read test status from container; docker exec exit code: ${exec_status}" >&2
  echo "[integration] Container kept running for inspection: ${CONTAINER_NAME}" >&2
  exit 1
fi

if [[ "${test_status}" == "0" ]]; then
  echo "[integration] Linux office integration test passed"
  echo "[integration] Container kept running for inspection: ${CONTAINER_NAME}"
else
  echo "[integration] Linux office integration test failed" >&2
  echo "[integration] Container kept running for inspection: ${CONTAINER_NAME}" >&2
fi

exit "${test_status}"
