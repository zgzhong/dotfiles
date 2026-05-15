# Dotfiles Sync Implementation Plan

> **Status:** Frozen design snapshot from 2026-04-07. Implementation has since landed and the code may have drifted from this document. Source of truth: repo source + `README.md` + `docs/machines.md`. See [`docs/superpowers/README.md`](../README.md).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate home directory dotfiles (gitconfig, tmux, fzf, codex/claude proxy, Rust, system PATH) into the chezmoi-managed dotfiles repo.

**Architecture:** Single-file chezmoi templates with inline `{{ if }}` conditionals for role/OS-specific content. New files for gitconfig, tmux, rust install script. Modifications to existing zshenv, zshrc, plugins, and dev-tools scripts.

**Tech Stack:** chezmoi templates (Go text/template), zsh, bash, Homebrew, Docker (integration tests)

**Spec:** `docs/superpowers/specs/2026-04-07-dotfiles-sync-design.md`

---

### Task 1: Add `.gitconfig` template

**Files:**
- Create: `dot_gitconfig.tmpl`
- Modify: `tests/integration/linux-office/run-e2e.sh`

- [ ] **Step 1: Write E2E assertions for gitconfig**

Add after the existing `assert_file_contains "$HOME/.zshrc" 'gwq completion zsh'` line (line 159) in `tests/integration/linux-office/run-e2e.sh`:

```bash
assert_file_contains "$HOME/.gitconfig" 'name = ZhongZegeng'
assert_file_contains "$HOME/.gitconfig" 'email = zhongzegeng@bytedance.com'
assert_file_contains "$HOME/.gitconfig" 'insteadOf = https://code.byted.org/'
assert_file_contains "$HOME/.gitconfig" 'directory = *'
assert_file_contains "$HOME/.gitconfig" 'clean = git-lfs clean -- %f'
```

- [ ] **Step 2: Create `dot_gitconfig.tmpl`**

```
# Managed by chezmoi.
[user]
	name = ZhongZegeng
{{ if eq .role "office" -}}
	email = zhongzegeng@bytedance.com
{{ else -}}
	email = zhong550413470@gmail.com
{{ end }}
{{ if eq .role "office" -}}
[url "git@code.byted.org:"]
	insteadOf = https://code.byted.org/
{{ end -}}
[safe]
	directory = *

[filter "lfs"]
	clean = git-lfs clean -- %f
	smudge = git-lfs smudge -- %f
	process = git-lfs filter-process
	required = true
```

- [ ] **Step 3: Commit**

```bash
git add dot_gitconfig.tmpl tests/integration/linux-office/run-e2e.sh
git commit -m "feat: add chezmoi-managed .gitconfig with role-based email"
```

---

### Task 2: Add `.tmux.conf` with `.chezmoiignore`

**Files:**
- Create: `dot_tmux.conf`
- Create: `.chezmoiignore`
- Modify: `tests/integration/linux-office/run-e2e.sh`

- [ ] **Step 1: Write E2E assertions for tmux.conf**

Add after the gitconfig assertions in `tests/integration/linux-office/run-e2e.sh`:

```bash
assert_file_contains "$HOME/.tmux.conf" 'default-terminal "tmux-256color"'
assert_file_contains "$HOME/.tmux.conf" 'mouse on'
```

- [ ] **Step 2: Create `dot_tmux.conf`**

```conf
# Managed by chezmoi.

# 让 tmux 用更匹配现代终端的 terminfo
set -g default-terminal "tmux-256color"

# (tmux 3.2+ 更推荐下面这行，若报错再删掉)
set -ga terminal-features ',xterm-256color:RGB'

# 更顺滑的交互
set -g mouse on
set -g focus-events on
```

- [ ] **Step 3: Create `.chezmoiignore`**

```
{{ if not (and (eq .role "office") (eq .chezmoi.os "linux")) }}
.tmux.conf
{{ end }}
```

- [ ] **Step 4: Commit**

```bash
git add dot_tmux.conf .chezmoiignore tests/integration/linux-office/run-e2e.sh
git commit -m "feat: add chezmoi-managed .tmux.conf (office+linux only)"
```

---

### Task 3: Update `.zshenv` — Rust env + `~/.local/bin`

**Files:**
- Modify: `dot_zshenv.tmpl`
- Modify: `tests/integration/linux-office/run-e2e.sh`

- [ ] **Step 1: Write E2E assertions for zshenv changes**

Add after the existing `assert_file_contains "$HOME/.zshenv" 'eval ...brew shellenv...'` line in `tests/integration/linux-office/run-e2e.sh`:

```bash
assert_file_contains "$HOME/.zshenv" 'RUSTUP_DIST_SERVER'
assert_file_contains "$HOME/.zshenv" 'cargo/env'
assert_file_contains "$HOME/.zshenv" '.local/bin'
```

- [ ] **Step 2: Append Rust env and local bin to `dot_zshenv.tmpl`**

Add after the closing `{{- end }}` on line 17:

```bash

# Rust
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

{{ if and (eq .role "office") (eq .chezmoi.os "linux") -}}
# local bin
export PATH="$HOME/.local/bin:$PATH"
{{- end }}
```

- [ ] **Step 3: Commit**

```bash
git add dot_zshenv.tmpl tests/integration/linux-office/run-e2e.sh
git commit -m "feat: add Rust env and ~/.local/bin to zshenv"
```

---

### Task 4: Add fzf — brew formula + antidote plugin + zshrc integration

**Files:**
- Modify: `run_onchange_after_30-install-dev-tools.sh.tmpl`
- Modify: `dot_zsh_plugins.txt.tmpl`
- Modify: `dot_zshrc.tmpl`
- Modify: `tests/integration/linux-office/run-e2e.sh`

- [ ] **Step 1: Write E2E assertions for fzf**

Add `fzf` to the `FORMULAE` array in `tests/integration/linux-office/run-e2e.sh` (after `unar`):

```bash
  fzf
```

Add file content assertions:

```bash
assert_file_contains "$HOME/.zsh_plugins.txt" 'Aloxaf/fzf-tab'
assert_file_contains "$HOME/.zshrc" 'brew --prefix fzf'
assert_file_contains "$HOME/.zshrc" 'key-bindings.zsh'
assert_file_contains "$HOME/.zshrc" 'completion.zsh'
```

- [ ] **Step 2: Add `fzf` to brew formulae**

In `run_onchange_after_30-install-dev-tools.sh.tmpl`, add `fzf` to `common_formulae` array (after `unar`):

```bash
  fzf
```

- [ ] **Step 3: Add fzf-tab to antidote plugins**

Append to `dot_zsh_plugins.txt.tmpl` (after `zsh-users/zsh-syntax-highlighting`):

```
Aloxaf/fzf-tab
```

- [ ] **Step 4: Add fzf integration to zshrc**

In `dot_zshrc.tmpl`, add after the `compinit -u` block (line 22) and before `# --- pure prompt ---`:

```bash

# --- fzf ---
[[ -f "$(brew --prefix fzf)/shell/key-bindings.zsh" ]] && source "$(brew --prefix fzf)/shell/key-bindings.zsh"
[[ -f "$(brew --prefix fzf)/shell/completion.zsh" ]] && source "$(brew --prefix fzf)/shell/completion.zsh"
```

- [ ] **Step 5: Commit**

```bash
git add run_onchange_after_30-install-dev-tools.sh.tmpl dot_zsh_plugins.txt.tmpl dot_zshrc.tmpl tests/integration/linux-office/run-e2e.sh
git commit -m "feat: add fzf with key-bindings, completion, and fzf-tab plugin"
```

---

### Task 5: Add codex/claude proxy functions + codex completion to zshrc

**Files:**
- Modify: `dot_zshrc.tmpl`
- Modify: `tests/integration/linux-office/run-e2e.sh`

- [ ] **Step 1: Write E2E assertions**

Add to `tests/integration/linux-office/run-e2e.sh`:

```bash
assert_file_contains "$HOME/.zshrc" 'codex()'
assert_file_contains "$HOME/.zshrc" 'claude()'
assert_file_contains "$HOME/.zshrc" '127.0.0.1:20170'
assert_file_contains "$HOME/.zshrc" 'codex completion zsh'
```

- [ ] **Step 2: Add codex/claude proxy functions to zshrc**

In `dot_zshrc.tmpl`, add after the `# --- completions (tools) ---` section (after gwq completion block, at the end of file):

```bash

# --- AI tools (proxy wrappers) ---
{{ $proxy := "http://127.0.0.1:1088" -}}
{{ if and (eq .role "office") (eq .chezmoi.os "linux") -}}
{{   $proxy = "http://127.0.0.1:20170" -}}
{{ end -}}
codex() {
  HTTP_PROXY={{ $proxy }} HTTPS_PROXY={{ $proxy }} \
  http_proxy={{ $proxy }} https_proxy={{ $proxy }} \
  command "${HOMEBREW_PREFIX}/bin/codex" "$@"
}

claude() {
  HTTP_PROXY={{ $proxy }} HTTPS_PROXY={{ $proxy }} \
  http_proxy={{ $proxy }} https_proxy={{ $proxy }} \
  command "${HOMEBREW_PREFIX}/bin/claude" "$@"
}

# --- codex completion ---
if command -v codex >/dev/null 2>&1; then
  source <(codex completion zsh)
fi
```

Note on Go template scoping: `$proxy :=` (with colon) creates a new scoped variable; `$proxy =` (without colon) reassigns the outer variable. The default is set before the `if` so it's accessible in the shell code below.

- [ ] **Step 3: Commit**

```bash
git add dot_zshrc.tmpl tests/integration/linux-office/run-e2e.sh
git commit -m "feat: add codex/claude proxy wrappers and codex completion"
```

---

### Task 6: Add system PATH (office + linux) to zshrc

**Files:**
- Modify: `dot_zshrc.tmpl`
- Modify: `tests/integration/linux-office/run-e2e.sh`

- [ ] **Step 1: Write E2E assertions**

Add to `tests/integration/linux-office/run-e2e.sh`:

```bash
assert_file_contains "$HOME/.zshrc" '/opt/tiger/ss_bin'
assert_file_contains "$HOME/.zshrc" '/opt/tiger/typhoon-blade'
```

- [ ] **Step 2: Add system PATH block to zshrc**

In `dot_zshrc.tmpl`, add after the existing `# --- PATH ---` section (after the GOPATH line):

```bash

{{ if and (eq .role "office") (eq .chezmoi.os "linux") -}}
# --- system PATH (office + linux) ---
export PATH=/opt/tiger/ss_bin:$PATH
export PATH=/opt/tiger/typhoon-blade:$PATH
{{- end }}
```

- [ ] **Step 3: Commit**

```bash
git add dot_zshrc.tmpl tests/integration/linux-office/run-e2e.sh
git commit -m "feat: add system PATH for office+linux (ss_bin, blade)"
```

---

### Task 7: Add Rust install script + `claude` brew cask

**Files:**
- Create: `run_once_before_25-install-rust.sh.tmpl`
- Modify: `run_onchange_after_30-install-dev-tools.sh.tmpl`
- Modify: `tests/integration/linux-office/run-e2e.sh`

- [ ] **Step 1: Write E2E assertions**

Add cask assertion after the existing `codex` cask check in `tests/integration/linux-office/run-e2e.sh`:

```bash
if brew list --cask claude >/dev/null 2>&1; then
  echo "[OK] cask installed: claude"
else
  echo "[ERROR] Missing cask: claude" >&2
  dump_debug
  exit 1
fi
```

Add rustc validation (new phase after "validate common casks"):

```bash
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
```

- [ ] **Step 2: Create `run_once_before_25-install-rust.sh.tmpl`**

```bash
#!/usr/bin/env bash
set -euo pipefail

{{ template "proxy-lib.sh.tmpl" . }}

os="{{ .chezmoi.os }}"
role="{{ .role | default "" }}"

setup_office_linux_proxy "$os" "$role"

# Rust mirrors (China mainland acceleration)
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"

if command -v rustup >/dev/null 2>&1; then
  echo "[chezmoi] Rust already installed: $(rustup --version)"
  exit 0
fi

# Also check if rustup is in cargo bin but not yet in PATH
if [[ -x "$HOME/.cargo/bin/rustup" ]]; then
  echo "[chezmoi] Rust already installed: $($HOME/.cargo/bin/rustup --version)"
  exit 0
fi

echo "[chezmoi] Installing Rust via rustup..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

echo "[chezmoi] Rust installed: $($HOME/.cargo/bin/rustup --version)"
```

- [ ] **Step 3: Add `claude` to common casks**

In `run_onchange_after_30-install-dev-tools.sh.tmpl`, add `claude` to `common_casks` array:

```bash
common_casks=(
  codex
  claude
)
```

- [ ] **Step 4: Commit**

```bash
git add run_once_before_25-install-rust.sh.tmpl run_onchange_after_30-install-dev-tools.sh.tmpl tests/integration/linux-office/run-e2e.sh
git commit -m "feat: add Rust install script and claude brew cask"
```

---

### Task 8: Run integration test

**Files:** None (test-only)

- [ ] **Step 1: Run the Docker-based integration test**

```bash
cd /data00/home/zhongzegeng/src/dotfiles
bash tests/integration/run-linux-office.sh
```

Expected: All phases pass, including new assertions for gitconfig, tmux, zshenv Rust/local-bin, fzf, codex/claude proxy, system PATH, Rust installation, and claude cask.

- [ ] **Step 2: If test fails, inspect logs and fix**

```bash
docker logs dotfiles-it-linux-office 2>&1 | tail -60
```

Fix issues and re-run until all assertions pass.

- [ ] **Step 3: Commit any test fixes**

```bash
git add -A
git commit -m "fix: address integration test failures"
```
