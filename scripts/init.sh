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
    printf '  1) office - work macOS or office Linux cloud dev\n'
    printf '  2) home   - personal macOS, including Mac mini M4\n'
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
case "${ROLE}" in
  home) role_description="personal macOS / Mac mini M4" ;;
  office) role_description="work macOS or office Linux cloud dev" ;;
esac
log "dotfiles deployed (role=${ROLE}, ${role_description})"
log "Restart your shell or run: exec zsh"
