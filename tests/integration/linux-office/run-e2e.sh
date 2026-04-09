#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/integration/linux-office/assertions.sh
source "${SCRIPT_DIR}/assertions.sh"

WORKSPACE="${WORKSPACE:-/workspace}"
LOG_DIR="${LOG_DIR:-/tmp/dotfiles-integration-logs}"
mkdir -p "$LOG_DIR"

FORMULAE=(
  git
  ripgrep
  eza
  bat
  zsh
  zoxide
  antidote
  lazygit
  mise
  d-kuro/tap/gwq
  jq
  htop
  zstd
  vim
  unar
  fzf
  fd
)

resolve_brew_shellenv_local() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  local candidates=(
    /home/linuxbrew/.linuxbrew/bin/brew
    "$HOME/.linuxbrew/bin/brew"
  )

  local brew_bin
  for brew_bin in "${candidates[@]}"; do
    if [[ -x "$brew_bin" ]]; then
      eval "$("$brew_bin" shellenv)"
      break
    fi
  done

  command -v brew >/dev/null 2>&1
}

dump_debug() {
  set +e
  echo "\n[DEBUG] ===== Diagnostic info =====" >&2
  echo "[DEBUG] User: $(whoami)" >&2
  echo "[DEBUG] HOME: $HOME" >&2
  echo "[DEBUG] Workspace: $WORKSPACE" >&2
  chezmoi --version >&2 || true
  chezmoi -S "$WORKSPACE" data >&2 || true
  if resolve_brew_shellenv_local; then
    brew --version >&2 || true
    brew config >&2 || true
  else
    echo "[DEBUG] brew not found" >&2
  fi
  echo "[DEBUG] ===== End diagnostic =====" >&2
}

run_step() {
  local name="$1"
  shift
  local log_file="${LOG_DIR}/${name}.log"

  phase "$name"
  {
    echo "+ $*"
    "$@"
  } >"$log_file" 2>&1 || {
    echo "[ERROR] Step failed: ${name}" >&2
    echo "[ERROR] Log: ${log_file}" >&2
    sed -n '1,240p' "$log_file" >&2 || true
    dump_debug
    exit 1
  }
}

assert_chezmoi_diff_clean() {
  local raw_log="${LOG_DIR}/chezmoi-diff.log"
  local filtered_log="${LOG_DIR}/chezmoi-diff.filtered.log"

  awk '
    /^\+ chezmoi .* diff$/ { next }
    /^chezmoi: warning: config file template has changed, run chezmoi init to regenerate config file$/ { next }
    { print }
  ' "$raw_log" >"$filtered_log"

  assert_empty_file "$filtered_log"
}

phase "write office config"
mkdir -p "$HOME/.config/chezmoi"
cp "$WORKSPACE/tests/integration/linux-office/testdata/chezmoi.toml" "$HOME/.config/chezmoi/chezmoi.toml"
assert_file_contains "$HOME/.config/chezmoi/chezmoi.toml" 'role = "office"'

run_step "chezmoi-apply-first" chezmoi -S "$WORKSPACE" apply -v

phase "validate brew installation"
if ! resolve_brew_shellenv_local; then
  echo "[ERROR] brew not found after chezmoi apply" >&2
  dump_debug
  exit 1
fi
brew --version >/dev/null

phase "validate formulae"
for pkg in "${FORMULAE[@]}"; do
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    echo "[OK] formula installed: $pkg"
  else
    echo "[ERROR] Missing formula: $pkg" >&2
    dump_debug
    exit 1
  fi
done


phase "validate common casks"
if brew list --cask codex >/dev/null 2>&1; then
  echo "[OK] cask installed: codex"
else
  echo "[ERROR] Missing cask: codex" >&2
  dump_debug
  exit 1
fi
# claude cask is macOS-only, skip on Linux

phase "validate rust installation"
if command -v rustc >/dev/null 2>&1; then
  echo "[OK] rustc installed: $(rustc --version)"
else
  # Source cargo env in case PATH isn't set yet
  [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
  if command -v rustc >/dev/null 2>&1; then
    echo "[OK] rustc installed (after sourcing cargo/env): $(rustc --version)"
  else
    echo "[ERROR] rustc not found after chezmoi apply" >&2
    dump_debug
    exit 1
  fi
fi

phase "validate go installation"
eval "$(mise activate bash)"
if command -v go >/dev/null 2>&1; then
  echo "[OK] go installed: $(go version)"
else
  echo "[ERROR] go not found after chezmoi apply" >&2
  dump_debug
  exit 1
fi

phase "validate go proxy config"
GOPROXY_VAL=$(go env GOPROXY)
if [[ "$GOPROXY_VAL" == *"goproxy.byted.org"* ]]; then
  echo "[OK] GOPROXY configured: $GOPROXY_VAL"
else
  echo "[ERROR] GOPROXY not configured correctly: $GOPROXY_VAL" >&2
  dump_debug
  exit 1
fi

GOPRIVATE_VAL=$(go env GOPRIVATE)
if [[ "$GOPRIVATE_VAL" == *"gitlab.everphoto.cn"* ]]; then
  echo "[OK] GOPRIVATE configured: $GOPRIVATE_VAL"
else
  echo "[ERROR] GOPRIVATE not configured correctly: $GOPRIVATE_VAL" >&2
  dump_debug
  exit 1
fi

phase "validate rendered files"
assert_file_contains "$HOME/.config/shell/env" 'export DOTFILES_ROLE="office"'
assert_file_contains "$HOME/.config/shell/env" 'export DOTFILES_OS="linux"'
assert_file_contains "$HOME/.config/shell/env" 'export DOTFILES_WORK_CONTEXT="1"'
assert_file_not_contains "$HOME/.config/shell/env" 'DOTFILES_HOME_CONTEXT'

assert_file_contains "$HOME/.vimrc" 'let mapleader=","'
assert_file_contains "$HOME/.vimrc" 'set number'
assert_file_contains "$HOME/.zshenv" '/home/linuxbrew/.linuxbrew/bin/brew'
assert_file_contains "$HOME/.zshenv" 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
assert_file_contains "$HOME/.zshenv" 'RUSTUP_DIST_SERVER'
assert_file_contains "$HOME/.zshenv" 'cargo/env'
assert_file_contains "$HOME/.zshenv" '.local/bin'
assert_file_contains "$HOME/.zshrc" 'antidote'
assert_file_contains "$HOME/.zsh_plugins.txt" 'zsh-users/zsh-autosuggestions'
assert_file_contains "$HOME/.zsh_plugins.txt" 'zsh-users/zsh-syntax-highlighting'
assert_file_contains "$HOME/.zsh_plugins.txt" 'sindresorhus/pure'
assert_file_contains "$HOME/.zsh_plugins.txt" 'zsh-users/zsh-completions'
assert_file_contains "$HOME/.zshrc" 'prompt pure'
assert_file_contains "$HOME/.zshrc" "alias lg='lazygit'"
assert_file_contains "$HOME/.zshrc" "alias ls='eza -Th -s type -L1'"
assert_file_contains "$HOME/.zshrc" 'alias s='
assert_file_contains "$HOME/.zshrc" 'alias k='
assert_file_contains "$HOME/.zshrc" 'export EDITOR=vim'
assert_file_contains "$HOME/.zshrc" 'no_proxy='
assert_file_contains "$HOME/.zshrc" 'mise activate zsh'
assert_file_contains "$HOME/.zshenv" 'GOBIN'
assert_file_contains "$HOME/.zshrc" 'GOBIN'
assert_file_contains "$HOME/.zshrc" 'gwq completion zsh'
assert_file_contains "$HOME/.gitconfig" 'name = ZhongZegeng'
assert_file_contains "$HOME/.gitconfig" 'email = zhongzegeng@bytedance.com'
assert_file_contains "$HOME/.gitconfig" 'insteadOf = https://code.byted.org/'
assert_file_contains "$HOME/.gitconfig" 'directory = *'
assert_file_contains "$HOME/.gitconfig" 'clean = git-lfs clean -- %f'
assert_file_contains "$HOME/.tmux.conf" 'default-terminal "tmux-256color"'
assert_file_contains "$HOME/.tmux.conf" 'mouse on'
assert_file_contains "$HOME/.zsh_plugins.txt" 'Aloxaf/fzf-tab'
assert_file_contains "$HOME/.zshrc" 'FZF_DEFAULT_COMMAND'
assert_file_contains "$HOME/.zshrc" 'FZF_ALT_C_COMMAND'
assert_file_contains "$HOME/.zshrc" 'brew --prefix fzf'
assert_file_contains "$HOME/.zshrc" 'key-bindings.zsh'
assert_file_contains "$HOME/.zshrc" 'completion.zsh'
assert_file_contains "$HOME/.zshrc" 'codex()'
assert_file_contains "$HOME/.zshrc" 'claude()'
assert_file_contains "$HOME/.zshrc" '127.0.0.1:20170'
assert_file_contains "$HOME/.zshrc" 'codex completion zsh'
assert_file_contains "$HOME/.zshrc" '/opt/tiger/ss_bin'
assert_file_contains "$HOME/.zshrc" '/opt/tiger/typhoon-blade'
assert_file_contains "$HOME/.zshrc" 'CODEX_HOME'
assert_file_contains "$HOME/.zshrc" '.zsh/completions'
assert_file_contains "$HOME/.zshrc" 'zoxide init zsh'
assert_file_contains "$HOME/.zsh_plugins.txt" 'ohmyzsh/ohmyzsh'
assert_file_contains "$HOME/.zshrc" 'goproxy-token-check'
assert_file_exists "$HOME/.local/bin/goproxy-token-check"
assert_file_contains "$HOME/.local/bin/goproxy-token-check" 'goproxy.byted.org'
assert_file_contains "$HOME/.local/bin/goproxy-token-check" 'goproxy_setup_cli'
assert_file_contains "$HOME/.local/bin/goproxy-token-check" 'Renew now?'

phase "validate zsh non-interactive startup"
run_step "zsh-non-interactive-smoke" zsh -c 'command -v brew >/dev/null && command -v zsh >/dev/null && command -v lazygit >/dev/null'

phase "validate zsh startup"
run_step "zsh-smoke" zsh -ic 'command -v antidote >/dev/null && [[ -n "${DOTFILES_ROLE:-}" ]] && [[ -n "${DOTFILES_OS:-}" ]] && (( ${+functions[prompt_pure_setup]} ))'

run_step "chezmoi-apply-second" chezmoi -S "$WORKSPACE" apply -v
run_step "chezmoi-diff" chezmoi -S "$WORKSPACE" diff
assert_chezmoi_diff_clean

phase "negative test: empty role must fail"
NEG_HOME="$(mktemp -d)"
NEG_LOG="${LOG_DIR}/negative-empty-role.log"
mkdir -p "$NEG_HOME/.config/chezmoi"
cat >"$NEG_HOME/.config/chezmoi/chezmoi.toml" <<'NEGEOF'
[data]
role = ""
NEGEOF

if env HOME="$NEG_HOME" XDG_CONFIG_HOME="$NEG_HOME/.config" chezmoi -S "$WORKSPACE" apply >"$NEG_LOG" 2>&1; then
  rm -rf "$NEG_HOME"
  echo "[ERROR] Expected chezmoi apply to fail when role is empty" >&2
  dump_debug
  exit 1
fi
assert_file_contains "$NEG_LOG" "data.role is required"
assert_file_contains "$NEG_LOG" "Allowed values: office, home"
rm -rf "$NEG_HOME"

phase "integration test passed"
echo "All Linux office integration checks passed. Logs: $LOG_DIR"
