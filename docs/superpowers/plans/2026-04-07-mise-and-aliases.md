# mise & aliases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace pyenv/goenv with mise for language SDK management, and sync aliases + shell config into chezmoi-managed `dot_zshrc.tmpl` with role-based conditionals.

**Architecture:** Two files are modified: the brew install script swaps `goenv`/`pyenv` for `mise`, and the zshrc template gains alias, env, proxy, mise activation, PATH, and completion blocks. Office-specific config uses chezmoi `{{ if eq .role "office" }}` guards.

**Tech Stack:** chezmoi templates, zsh, Homebrew, mise

---

### Task 1: Update brew formulae — replace pyenv/goenv with mise

**Files:**
- Modify: `run_onchange_after_30-install-dev-tools.sh.tmpl:18-35` (common_formulae array)

- [ ] **Step 1: Remove `goenv` and `pyenv`, add `mise` in `common_formulae`**

Replace the `common_formulae` block so it reads:

```bash
common_formulae=(
  git
  ripgrep
  eza
  bat
  zsh
  autojump
  antidote
  lazygit
  mise
  d-kuro/tap/gwq
  jq
  htop
  zstd
  vim
  unar
)
```

Changes: `goenv` and `pyenv` removed, `mise` added in their place.

- [ ] **Step 2: Verify the template renders correctly**

Run:

```bash
chezmoi -S . cat run_onchange_after_30-install-dev-tools.sh.tmpl 2>/dev/null | head -40
```

Expected: the `common_formulae` array should contain `mise` and NOT contain `goenv` or `pyenv`.

- [ ] **Step 3: Commit**

```bash
git add run_onchange_after_30-install-dev-tools.sh.tmpl
git commit -m "feat(brew): replace pyenv/goenv with mise in common formulae"
```

---

### Task 2: Add aliases, env, proxy, mise, PATH, and completions to dot_zshrc.tmpl

**Files:**
- Modify: `dot_zshrc.tmpl:27` (append after `prompt pure`)

- [ ] **Step 1: Append all new blocks after the `prompt pure` line**

Add the following content after line 27 (`prompt pure`):

```zsh

# --- aliases ---
alias cls='clear'
alias ls='eza -Th -s type -L1'
alias ll='ls -l'
alias sl='ls'
alias la='ls -a'
alias grep="rg --color=auto -glob='!.{.bzr,git,hg,idea,vscode}'"
alias gerp='grep'
alias lg='lazygit'
alias vi='vim'

{{ if eq .role "office" -}}
# --- office-only aliases ---
alias s='ssh -K zhongzegeng@BYTEDANCE.COM'
alias k='kinit --keychain zhongzegeng@BYTEDANCE.COM'
{{- end }}

# --- environment ---
export LC_TIME="en_US.UTF-8"
export EDITOR=vim

{{ if eq .role "office" -}}
# --- office proxy ---
export no_proxy="localhost,.byted.org,byted.org,.bytedance.net,bytedance.net,.byteintl.net,byteintl.net,127.0.0.1,127.0.0.0/8,169.254.0.0/16,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16,10.0.0.0/8,::1,fe80::/10,fd00::/8"

set_proxy() {
  export http_proxy=http://sys-proxy-rd-relay.byted.org:8118 \
         https_proxy=http://sys-proxy-rd-relay.byted.org:8118
}

unset_proxy() {
  unset http_proxy https_proxy no_proxy
}
{{- end }}

# --- mise (language SDK manager) ---
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# --- PATH ---
export PATH="$GOROOT/bin:$PATH"
export PATH="$PATH:$GOPATH/bin"

# --- completions (tools) ---
if command -v gwq >/dev/null 2>&1; then
  source <(gwq completion zsh)
fi
```

- [ ] **Step 2: Verify template renders for office role**

Run:

```bash
chezmoi -S . execute-template < dot_zshrc.tmpl 2>/dev/null
```

Expected output should contain:
- All common aliases (`alias cls=`, `alias ls='eza`, etc.)
- Office aliases (`alias s=`, `alias k=`)
- Office proxy block (`no_proxy`, `set_proxy`, `unset_proxy`)
- mise activation block
- PATH exports
- gwq completion block

- [ ] **Step 3: Commit**

```bash
git add dot_zshrc.tmpl
git commit -m "feat(zsh): add aliases, env, proxy, mise activation, and completions"
```

---

### Task 3: Update integration test to match new formulae

**Files:**
- Modify: `tests/integration/linux-office/run-e2e.sh:12-29` (FORMULAE array)

- [ ] **Step 1: Update the FORMULAE array in the e2e test**

Replace the `FORMULAE` array so it reads:

```bash
FORMULAE=(
  git
  ripgrep
  eza
  bat
  zsh
  autojump
  antidote
  lazygit
  mise
  d-kuro/tap/gwq
  jq
  htop
  zstd
  vim
  unar
)
```

Changes: `goenv` and `pyenv` removed, `mise` added — mirrors the updated `common_formulae`.

- [ ] **Step 2: Add assertions for new zshrc content**

After the existing `assert_file_contains "$HOME/.zshrc" 'prompt pure'` line (line 151), add:

```bash
assert_file_contains "$HOME/.zshrc" "alias lg='lazygit'"
assert_file_contains "$HOME/.zshrc" "alias ls='eza -Th -s type -L1'"
assert_file_contains "$HOME/.zshrc" 'alias s='
assert_file_contains "$HOME/.zshrc" 'alias k='
assert_file_contains "$HOME/.zshrc" 'export EDITOR=vim'
assert_file_contains "$HOME/.zshrc" 'no_proxy='
assert_file_contains "$HOME/.zshrc" 'mise activate zsh'
assert_file_contains "$HOME/.zshrc" 'GOROOT'
assert_file_contains "$HOME/.zshrc" 'gwq completion zsh'
```

- [ ] **Step 3: Commit**

```bash
git add tests/integration/linux-office/run-e2e.sh
git commit -m "test: update e2e assertions for mise and new zshrc content"
```

---

### Task 4: Run integration test and verify

- [ ] **Step 1: Run the linux-office integration test**

```bash
cd /data00/home/zhongzegeng/src/dotfiles
bash tests/integration/run-linux-office.sh
```

Expected: `[integration] Linux office integration test passed`

- [ ] **Step 2: If test fails, inspect logs and fix**

```bash
docker exec dotfiles-it-linux-office cat /tmp/dotfiles-integration-logs/chezmoi-apply-first.log | tail -50
```

Fix any issues in the template files and re-run.

- [ ] **Step 3: Final commit if any fixes were needed**

```bash
git add -A && git commit -m "fix: address integration test feedback"
```
