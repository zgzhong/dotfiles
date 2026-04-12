#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
LOG_DIR="${LOG_DIR:-/tmp/dotfiles-cold-boot-logs}"
mkdir -p "$LOG_DIR"

# Reuse assertions from existing test suite
# shellcheck source=tests/integration/linux-office/assertions.sh
source "${WORKSPACE}/tests/integration/linux-office/assertions.sh"

# --- Step 1: Install chezmoi (same as bootstrap.sh) -----------------------

phase "install chezmoi"
CHEZMOI_BIN_DIR="${HOME}/.local/bin"
mkdir -p "${CHEZMOI_BIN_DIR}"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${CHEZMOI_BIN_DIR}"
export PATH="${CHEZMOI_BIN_DIR}:${PATH}"
chezmoi --version

assert_file_exists "${CHEZMOI_BIN_DIR}/chezmoi"
echo "[OK] chezmoi installed to ${CHEZMOI_BIN_DIR}"

# --- Step 2: Init from local workspace (simulates chezmoi init) -----------
#
# In the real cold-boot flow, `chezmoi init zgzhong/dotfiles` clones the repo
# to ~/.local/share/chezmoi. In the test, the repo is mounted read-only at
# /workspace. We symlink the default source path to the workspace so that
# `chezmoi apply` (called by init.sh without -S flag) finds the source state.

phase "chezmoi init from local workspace"
CHEZMOI_SOURCE_DIR="${HOME}/.local/share/chezmoi"
mkdir -p "$(dirname "${CHEZMOI_SOURCE_DIR}")"
ln -s "${WORKSPACE}" "${CHEZMOI_SOURCE_DIR}"
echo "[OK] chezmoi source linked to ${WORKSPACE}"

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
