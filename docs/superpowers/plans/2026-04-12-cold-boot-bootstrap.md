# Cold Boot: One-Line Dotfiles Bootstrap — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a one-line `curl | bash` cold-boot mechanism that installs chezmoi and deploys dotfiles on a brand-new macOS or Debian Linux machine.

**Architecture:** A remote `scripts/bootstrap.sh` (POSIX sh) installs chezmoi to `~/bin` and clones the repo, then hands off to an in-repo `scripts/init.sh` (bash) that interactively selects the machine role, generates `chezmoi.toml`, and runs `chezmoi apply`. A separate Docker-based cold-boot integration test validates the chain end-to-end.

**Tech Stack:** POSIX sh, bash, chezmoi, Docker (for testing)

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `scripts/bootstrap.sh` | Remote bootstrap: install chezmoi, clone repo, exec init.sh |
| Create | `scripts/init.sh` | In-repo init: role selection, config generation, chezmoi apply |
| Create | `tests/integration/cold-boot/Dockerfile` | Minimal Debian 12 image (curl only, no chezmoi) |
| Create | `tests/integration/cold-boot/run-e2e.sh` | Container-side cold-boot test |
| Create | `tests/integration/run-cold-boot.sh` | Host-side test entry point |
| Modify | `.chezmoiignore` | Add `scripts/` to prevent deployment to ~ |
| Modify | `README.md:16-34` | Replace manual bootstrap with one-liner |

---

### Task 1: Add `scripts/` to `.chezmoiignore`

**Files:**
- Modify: `.chezmoiignore`

- [ ] **Step 1: Add scripts/ exclusion to .chezmoiignore**

Open `.chezmoiignore` and append `scripts/` at the end. The current content is:

```
{{ if not (and (eq .role "office") (eq .chezmoi.os "linux")) }}
.tmux.conf
{{ end }}
{{ if ne .role "office" }}
.local/bin/goproxy-token-check
{{ end }}
```

Add after the last line:

```
scripts/
```

This prevents chezmoi from deploying the `scripts/` directory to `~/scripts/`.

- [ ] **Step 2: Verify with chezmoi managed**

Run (from repo root):

```bash
chezmoi managed -S . | grep -c scripts
```

Expected: `0` (no scripts/ files in managed list).

- [ ] **Step 3: Commit**

```bash
git add .chezmoiignore
git commit -m "chore: ignore scripts/ directory in chezmoi"
```

---

### Task 2: Create `scripts/bootstrap.sh`

**Files:**
- Create: `scripts/bootstrap.sh`

- [ ] **Step 1: Create the bootstrap script**

Create `scripts/bootstrap.sh` with the following content. This is pure POSIX sh with `curl` as the only external dependency:

```sh
#!/bin/sh
set -eu

GITHUB_REPO="zgzhong/dotfiles"
CHEZMOI_BIN_DIR="${HOME}/bin"

log() {
  printf '[bootstrap] %s\n' "$*"
}

die() {
  printf '[bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

# --- Pre-checks -----------------------------------------------------------

command -v curl >/dev/null 2>&1 || die "curl is required but not found"

# --- Install chezmoi -------------------------------------------------------

if command -v chezmoi >/dev/null 2>&1; then
  log "chezmoi already installed: $(chezmoi --version)"
else
  log "Installing chezmoi to ${CHEZMOI_BIN_DIR} ..."
  mkdir -p "${CHEZMOI_BIN_DIR}"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${CHEZMOI_BIN_DIR}" \
    || die "Failed to install chezmoi"
  export PATH="${CHEZMOI_BIN_DIR}:${PATH}"
  chezmoi --version >/dev/null 2>&1 \
    || die "chezmoi installed but not executable"
  log "chezmoi installed: $(chezmoi --version)"
fi

# --- Clone repository ------------------------------------------------------

log "Initializing dotfiles from ${GITHUB_REPO} ..."
chezmoi init "${GITHUB_REPO}" --apply=false \
  || die "chezmoi init failed"

# --- Hand off to init.sh --------------------------------------------------

INIT_SCRIPT="$(chezmoi source-path)/scripts/init.sh"
if [ ! -f "${INIT_SCRIPT}" ]; then
  die "init.sh not found at ${INIT_SCRIPT}"
fi

log "Handing off to init.sh ..."
exec bash "${INIT_SCRIPT}"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/bootstrap.sh
```

- [ ] **Step 3: Run shellcheck**

```bash
shellcheck scripts/bootstrap.sh
```

Expected: no errors or warnings.

- [ ] **Step 4: Commit**

```bash
git add scripts/bootstrap.sh
git commit -m "feat: add bootstrap.sh — remote cold-boot entry point"
```

---

### Task 3: Create `scripts/init.sh`

**Files:**
- Create: `scripts/init.sh`

- [ ] **Step 1: Create the init script**

Create `scripts/init.sh` with the following content:

```bash
#!/usr/bin/env bash
set -euo pipefail

CHEZMOI_CONFIG_DIR="${HOME}/.config/chezmoi"
CHEZMOI_CONFIG_FILE="${CHEZMOI_CONFIG_DIR}/chezmoi.toml"

log() {
  printf '[init] %s\n' "$*"
}

die() {
  printf '[init] ERROR: %s\n' "$*" >&2
  exit 1
}

# --- Role selection --------------------------------------------------------

select_role() {
  # Environment variable bypass for CI / non-interactive use
  if [[ -n "${DOTFILES_ROLE:-}" ]]; then
    case "${DOTFILES_ROLE}" in
      office|home) log "Using role from environment: ${DOTFILES_ROLE}" ;;
      *) die "Invalid DOTFILES_ROLE: '${DOTFILES_ROLE}'. Allowed: office, home" ;;
    esac
    ROLE="${DOTFILES_ROLE}"
    return
  fi

  # Non-interactive terminal without DOTFILES_ROLE → error
  if [[ ! -t 0 ]]; then
    die "Interactive input required but stdin is not a terminal. Set DOTFILES_ROLE=office|home to run non-interactively."
  fi

  # Interactive menu
  while true; do
    printf '\nSelect your machine role:\n'
    printf '  1) office\n'
    printf '  2) home\n'
    printf 'Choice [1-2]: '
    read -r choice
    case "${choice}" in
      1) ROLE="office"; break ;;
      2) ROLE="home";   break ;;
      *) printf 'Invalid choice. Please enter 1 or 2.\n' ;;
    esac
  done

  log "Selected role: ${ROLE}"
}

# --- Generate chezmoi.toml ------------------------------------------------

generate_config() {
  if [[ -f "${CHEZMOI_CONFIG_FILE}" ]]; then
    if [[ -n "${DOTFILES_ROLE:-}" ]]; then
      # Non-interactive: overwrite silently
      log "Overwriting existing config (non-interactive mode)"
    else
      printf 'Config already exists at %s. Overwrite? (y/N): ' "${CHEZMOI_CONFIG_FILE}"
      read -r answer
      case "${answer}" in
        [yY]|[yY][eE][sS]) log "Overwriting existing config" ;;
        *)
          log "Keeping existing config"
          return
          ;;
      esac
    fi
  fi

  mkdir -p "${CHEZMOI_CONFIG_DIR}"
  cat > "${CHEZMOI_CONFIG_FILE}" <<EOF
[data]
role = "${ROLE}"
EOF

  log "Config written to ${CHEZMOI_CONFIG_FILE}"
}

# --- Apply -----------------------------------------------------------------

apply_dotfiles() {
  log "Running chezmoi apply ..."
  chezmoi apply
  log "chezmoi apply completed"
}

# --- Main ------------------------------------------------------------------

select_role
generate_config
apply_dotfiles

printf '\n'
log "dotfiles deployed (role=${ROLE})"
log "Restart your shell or run: exec zsh"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/init.sh
```

- [ ] **Step 3: Run shellcheck**

```bash
shellcheck scripts/init.sh
```

Expected: no errors or warnings.

- [ ] **Step 4: Commit**

```bash
git add scripts/init.sh
git commit -m "feat: add init.sh — interactive role selection and chezmoi apply"
```

---

### Task 4: Update README.md Bootstrap section

**Files:**
- Modify: `README.md:16-34`

- [ ] **Step 1: Replace the Bootstrap section**

Replace lines 16-34 of `README.md` (the current `## Bootstrap` section) with:

```markdown
## Bootstrap

One-liner for a fresh machine (requires `curl`):

```bash
curl -fsLS https://raw.githubusercontent.com/zgzhong/dotfiles/main/scripts/bootstrap.sh | bash
```

The script will:
1. Install `chezmoi` to `~/bin`
2. Clone this repo
3. Ask you to select a machine role (`office` or `home`)
4. Generate `~/.config/chezmoi/chezmoi.toml`
5. Run `chezmoi apply` (installs Homebrew, dev tools, shell config, etc.)

For non-interactive use (CI, containers):

```bash
curl -fsLS https://raw.githubusercontent.com/zgzhong/dotfiles/main/scripts/bootstrap.sh | DOTFILES_ROLE=office bash
```

<details>
<summary>Manual bootstrap (alternative)</summary>

1. Install chezmoi on the target machine.
2. Initialize from this repo:
   ```bash
   chezmoi init --source /path/to/this/repo
   ```
3. Create local machine config from the example in source state:
   ```bash
   mkdir -p ~/.config/chezmoi
   cp "$(chezmoi source-path)/dot_config/chezmoi/chezmoi.toml.example" ~/.config/chezmoi/chezmoi.toml
   ```
4. Edit `~/.config/chezmoi/chezmoi.toml` and set at least:
   - `data.role = "office"` or `"home"`
5. Preview and apply:
   ```bash
   chezmoi diff
   chezmoi apply --dry-run
   chezmoi apply
   ```

</details>
```

- [ ] **Step 2: Verify README renders correctly**

Skim the file to ensure Markdown syntax is correct (especially the nested code blocks inside the `<details>` block).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update Bootstrap section with one-line cold-boot command"
```

---

### Task 5: Create cold-boot test Dockerfile

**Files:**
- Create: `tests/integration/cold-boot/Dockerfile`

- [ ] **Step 1: Create the Dockerfile**

Create `tests/integration/cold-boot/Dockerfile`. This is based on the existing `tests/integration/linux-office/Dockerfile` but without the chezmoi installation step:

```dockerfile
FROM debian:12

ARG USERNAME=tester
ARG USER_UID=1000
ARG USER_GID=1000

# Use internal mirror for faster apt in office network
RUN sed -i 's|deb.debian.org|mirrors.byted.org|g' /etc/apt/sources.list.d/debian.sources

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    sudo \
    curl \
    ca-certificates \
    git \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
  && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/bash "${USERNAME}" \
  && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >"/etc/sudoers.d/${USERNAME}" \
  && chmod 0440 "/etc/sudoers.d/${USERNAME}"

# NOTE: chezmoi is NOT pre-installed — the cold-boot test installs it.

USER ${USERNAME}
WORKDIR /home/${USERNAME}

CMD ["bash"]
```

Note: `git` is added as an apt dependency because `chezmoi init` needs `git` to clone the repo, and unlike the linux-office test where Homebrew installs git, the cold-boot flow needs git available before `chezmoi init`.

- [ ] **Step 2: Commit**

```bash
git add tests/integration/cold-boot/Dockerfile
git commit -m "test: add cold-boot Dockerfile — minimal Debian with curl only"
```

---

### Task 6: Create cold-boot container-side test

**Files:**
- Create: `tests/integration/cold-boot/run-e2e.sh`

- [ ] **Step 1: Create the container-side test script**

Create `tests/integration/cold-boot/run-e2e.sh`. This script runs inside the container and simulates the cold-boot flow using the mounted local workspace:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${WORKSPACE:-/workspace}"
LOG_DIR="${LOG_DIR:-/tmp/dotfiles-cold-boot-logs}"
mkdir -p "$LOG_DIR"

# Reuse assertions from existing test suite
# shellcheck source=tests/integration/linux-office/assertions.sh
source "${WORKSPACE}/tests/integration/linux-office/assertions.sh"

# --- Step 1: Install chezmoi (same as bootstrap.sh) -----------------------

phase "install chezmoi"
CHEZMOI_BIN_DIR="${HOME}/bin"
mkdir -p "${CHEZMOI_BIN_DIR}"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${CHEZMOI_BIN_DIR}"
export PATH="${CHEZMOI_BIN_DIR}:${PATH}"
chezmoi --version

assert_file_exists "${CHEZMOI_BIN_DIR}/chezmoi"
echo "[OK] chezmoi installed to ${CHEZMOI_BIN_DIR}"

# --- Step 2: Init from local workspace (simulates chezmoi init) -----------

phase "chezmoi init from local workspace"
chezmoi init --source "${WORKSPACE}" --apply=false
echo "[OK] chezmoi init completed"

# --- Step 3: Run init.sh with DOTFILES_ROLE --------------------------------

phase "run init.sh"
export DOTFILES_ROLE=office
bash "${WORKSPACE}/scripts/init.sh"
echo "[OK] init.sh completed"

# --- Step 4: Verify cold-boot results -------------------------------------

phase "verify chezmoi config"
assert_file_exists "${HOME}/.config/chezmoi/chezmoi.toml"
assert_file_contains "${HOME}/.config/chezmoi/chezmoi.toml" 'role = "office"'
echo "[OK] chezmoi.toml contains correct role"

phase "verify key dotfiles exist"
assert_file_exists "${HOME}/.zshrc"
assert_file_exists "${HOME}/.zshenv"
assert_file_exists "${HOME}/.gitconfig"
assert_file_exists "${HOME}/.vimrc"
assert_file_exists "${HOME}/.config/shell/env"
echo "[OK] key dotfiles deployed"

phase "verify rendered content"
assert_file_contains "${HOME}/.config/shell/env" 'export DOTFILES_ROLE="office"'
assert_file_contains "${HOME}/.config/shell/env" 'export DOTFILES_OS="linux"'
assert_file_contains "${HOME}/.gitconfig" 'name = ZhongZegeng'
echo "[OK] rendered content is correct"

phase "cold-boot integration test passed"
echo "All cold-boot checks passed. Logs: $LOG_DIR"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x tests/integration/cold-boot/run-e2e.sh
```

- [ ] **Step 3: Run shellcheck**

```bash
shellcheck tests/integration/cold-boot/run-e2e.sh
```

Expected: no errors (possibly info-level notes about sourced files, which are OK).

- [ ] **Step 4: Commit**

```bash
git add tests/integration/cold-boot/run-e2e.sh
git commit -m "test: add cold-boot container-side e2e test"
```

---

### Task 7: Create cold-boot host-side test entry point

**Files:**
- Create: `tests/integration/run-cold-boot.sh`

- [ ] **Step 1: Create the host-side entry script**

Create `tests/integration/run-cold-boot.sh`. This follows the same container management pattern as the existing `tests/integration/run-linux-office.sh`:

```bash
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
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x tests/integration/run-cold-boot.sh
```

- [ ] **Step 3: Run shellcheck**

```bash
shellcheck tests/integration/run-cold-boot.sh
```

Expected: no errors or warnings.

- [ ] **Step 4: Commit**

```bash
git add tests/integration/run-cold-boot.sh
git commit -m "test: add cold-boot host-side test entry point"
```

---

### Task 8: Run the cold-boot integration test

**Files:**
- None (execution only)

- [ ] **Step 1: Run the cold-boot test**

```bash
tests/integration/run-cold-boot.sh
```

Expected: The test should:
1. Build the Docker image (Debian 12, curl only)
2. Start the container
3. Inside the container: install chezmoi, run init.sh with `DOTFILES_ROLE=office`, verify dotfiles
4. Report "Cold-boot integration test passed"

If the test fails, inspect the container:

```bash
docker exec -it dotfiles-it-cold-boot bash
```

- [ ] **Step 2: Fix any issues found during the test**

If the test fails, debug and fix. Common issues to check:
- `chezmoi init --source /workspace --apply=false` — ensure the workspace mount path is correct
- `init.sh` using `chezmoi apply` without `-S` flag — chezmoi should use its default source path after `init`
- Missing `git` in the container (needed by `chezmoi init`)

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix: address cold-boot test issues"
```

(Only if fixes were needed.)

---

### Task 9: Final verification — existing e2e still passes

**Files:**
- None (verification only)

- [ ] **Step 1: Run the existing linux-office e2e test**

```bash
tests/integration/run-linux-office.sh
```

Expected: "Linux office integration test passed" — confirming no regressions.

- [ ] **Step 2: Run shellcheck on all new scripts**

```bash
shellcheck scripts/bootstrap.sh scripts/init.sh tests/integration/cold-boot/run-e2e.sh tests/integration/run-cold-boot.sh
```

Expected: no errors.
