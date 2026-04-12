#!/bin/sh
set -eu

GITHUB_REPO="zgzhong/dotfiles"
CHEZMOI_BIN_DIR="${HOME}/.local/bin"

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

export PATH="${CHEZMOI_BIN_DIR}:${PATH}"

if command -v chezmoi >/dev/null 2>&1; then
  log "chezmoi already installed: $(chezmoi --version)"
else
  log "Installing chezmoi to ${CHEZMOI_BIN_DIR} ..."
  mkdir -p "${CHEZMOI_BIN_DIR}"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "${CHEZMOI_BIN_DIR}" \
    || die "Failed to install chezmoi"
  chezmoi --version >/dev/null 2>&1 \
    || die "chezmoi installed but not executable"
  log "chezmoi installed: $(chezmoi --version)"
fi

# --- Clone repository ------------------------------------------------------

CHEZMOI_SOURCE="$(chezmoi source-path 2>/dev/null || true)"
if [ -n "${CHEZMOI_SOURCE}" ] && [ -d "${CHEZMOI_SOURCE}" ]; then
  log "Dotfiles repo already present at ${CHEZMOI_SOURCE}, skipping init"
else
  log "Initializing dotfiles from ${GITHUB_REPO} ..."
  chezmoi init "${GITHUB_REPO}" --apply=false \
    || die "chezmoi init failed"
fi

# --- Hand off to init.sh --------------------------------------------------

INIT_SCRIPT="$(chezmoi source-path)/scripts/init.sh"
if [ ! -f "${INIT_SCRIPT}" ]; then
  die "init.sh not found at ${INIT_SCRIPT}"
fi

log "Handing off to init.sh ..."
exec bash "${INIT_SCRIPT}" </dev/tty
