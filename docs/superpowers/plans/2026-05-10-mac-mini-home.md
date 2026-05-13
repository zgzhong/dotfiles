# Mac mini M4 Home Dotfiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the dotfiles repository so a future bootstrap/init cleanly supports the Mac mini M4 as the `home + darwin` personal machine.

**Architecture:** Keep the existing chezmoi `role + OS` model. Express package differences with the current `common_*` and `macos_*` Homebrew arrays, add home/darwin shell behavior with narrow template conditionals, and keep repository docs/tests out of the target home directory through `.chezmoiignore`.

**Tech Stack:** chezmoi templates, Bash, Zsh, Homebrew, Vim config, Docker-based Linux integration tests.

---

## File Structure

- Modify `.chezmoi.toml.tmpl`: remove unused `machine_name` from default data.
- Modify `dot_config/chezmoi/chezmoi.toml.example`: remove unused `machine_name` from the sample local config.
- Modify `.chezmoiignore`: ignore repository maintenance files (`README.md`, `docs/`, `tests/`) while preserving existing deploy exclusions.
- Modify `run_onchange_after_30-install-dev-tools.sh.tmpl`: add confirmed common and macOS Homebrew formulae/casks.
- Modify `tests/integration/linux-office/run-e2e.sh`: extend common formula assertions for new shared packages.
- Modify `dot_zshrc.tmpl`: add the `home + darwin` terminal proxy helper.
- Modify `dot_vimrc`: replace current short config with the live-style bilingual lightweight Vim config.
- Modify `scripts/init.sh`: make role prompts and completion messages clearer without changing generated config shape.
- Modify `README.md`: fix machine model and package list drift.
- Modify `docs/machines.md`: document `home + darwin` as Mac mini M4 and remove `machine_name` from required data.

## Task 1: Update Common Formula Test Expectations

**Files:**
- Modify: `tests/integration/linux-office/run-e2e.sh`

- [ ] **Step 1: Add failing expectations for new common formulae**

In `tests/integration/linux-office/run-e2e.sh`, update the `FORMULAE` array so it includes `aria2` and `gh`. Keep alphabetical perfection out of scope; place them near other common CLI tools:

```bash
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
  aria2
  gh
)
```

- [ ] **Step 2: Verify test expectations mention both packages**

Run:

```bash
rg -n "aria2|gh" tests/integration/linux-office/run-e2e.sh
```

Expected: output includes `aria2` and `gh` inside the `FORMULAE` array.

- [ ] **Step 3: Commit**

```bash
git add tests/integration/linux-office/run-e2e.sh
git commit -m "test: expect new common Homebrew formulae"
```

## Task 2: Clean Machine Model and Ignore Repository Files

**Files:**
- Modify: `.chezmoi.toml.tmpl`
- Modify: `dot_config/chezmoi/chezmoi.toml.example`
- Modify: `.chezmoiignore`

- [ ] **Step 1: Remove `machine_name` from source defaults**

Edit `.chezmoi.toml.tmpl` to this content:

```toml
# Global defaults for this source state.
# Per-machine private values must be set in ~/.config/chezmoi/chezmoi.toml.

[data]
# Required: office | home
role = ""
```

- [ ] **Step 2: Remove `machine_name` from the sample local config**

Edit `dot_config/chezmoi/chezmoi.toml.example` to this content:

```toml
# Copy this file to ~/.config/chezmoi/chezmoi.toml and adjust per machine.

[data]
# office | home
role = "office"
```

- [ ] **Step 3: Ignore repository maintenance files**

Edit `.chezmoiignore` so it contains:

```gotemplate
{{ if not (and (eq .role "office") (eq .chezmoi.os "linux")) }}
.tmux.conf
{{ end }}
{{ if ne .role "office" }}
.local/bin/goproxy-token-check
{{ end }}
scripts/
README.md
docs/
tests/
```

- [ ] **Step 4: Verify home/darwin managed and ignored paths**

Run:

```bash
chezmoi --source . --override-data '{"role":"home"}' managed
chezmoi --source . --override-data '{"role":"home"}' ignored
```

Expected:

- `managed` includes `.zshrc`, `.zshenv`, `.zsh_plugins.txt`, `.config/shell/env`, `.gitconfig`, `.vimrc`, and `.profile`.
- `managed` does not include `README.md`, `docs`, or `tests`.
- `ignored` includes `.tmux.conf`, `.local/bin/goproxy-token-check`, `scripts`, `README.md`, `docs`, and `tests`.

- [ ] **Step 5: Commit**

```bash
git add .chezmoi.toml.tmpl dot_config/chezmoi/chezmoi.toml.example .chezmoiignore
git commit -m "fix: simplify machine model and ignore repo docs"
```

## Task 3: Update Homebrew Package Lists

**Files:**
- Modify: `run_onchange_after_30-install-dev-tools.sh.tmpl`

- [ ] **Step 1: Add confirmed common formulae**

In `run_onchange_after_30-install-dev-tools.sh.tmpl`, update `common_formulae` to include `aria2` and `gh`:

```bash
common_formulae=(
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
  aria2
  gh
)
```

- [ ] **Step 2: Add confirmed macOS formulae and cask**

In the same file, update the macOS arrays:

```bash
macos_formulae=(
  cirruslabs/cli/tart
  wget
)

macos_casks=(
  visual-studio-code
  iterm2
  orbstack
  trae
  keepassxc
)
```

- [ ] **Step 3: Verify package names are present exactly once**

Run:

```bash
rg -n "aria2|\\bgh\\b|cirruslabs/cli/tart|\\bwget\\b|keepassxc" run_onchange_after_30-install-dev-tools.sh.tmpl tests/integration/linux-office/run-e2e.sh
```

Expected:

- `aria2` and `gh` appear in both the install script and Linux office test.
- `cirruslabs/cli/tart`, `wget`, and `keepassxc` appear only in the install script.

- [ ] **Step 4: Commit**

```bash
git add run_onchange_after_30-install-dev-tools.sh.tmpl
git commit -m "feat: add personal macOS Homebrew packages"
```

## Task 4: Update Shell and Vim Targets

**Files:**
- Modify: `dot_zshrc.tmpl`
- Modify: `dot_vimrc`

- [ ] **Step 1: Add home/darwin proxy helper**

In `dot_zshrc.tmpl`, add this block after the existing office proxy block and before the zoxide block:

```gotemplate
{{ if and (eq .role "home") (eq .chezmoi.os "darwin") -}}
# --- home macOS proxy ---
set_proxy() {
  export http_proxy=http://127.0.0.1:1088
  export https_proxy=http://127.0.0.1:1088
}

unset_proxy() {
  unset http_proxy https_proxy
}
{{- end }}
```

Do not add the `vultr` alias. Do not add Powerlevel10k, `antigen`, `autojump`, `goenv`, `pyenv`, or Homebrew `FPATH` initialization.

- [ ] **Step 2: Replace `dot_vimrc` with live-style bilingual config**

Edit `dot_vimrc` to this content:

```vim
" Minimal, lightweight beautification for Vim (no plugins)
" Vim 轻量美化配置（不使用插件）

set nocompatible                 " use Vim defaults / 使用 Vim 默认行为

" Keymaps / 快捷键
let mapleader=","                " set leader key / 设置 Leader 键
nmap ; :                         " ; enters command-line mode / ; 进入命令行模式
noremap <Leader>y "*y            " yank to system clipboard / 复制到系统剪贴板
noremap <Leader>p "*p            " paste from system clipboard / 从系统剪贴板粘贴
nnoremap <C-h> <C-w>h            " move to left window / 切到左侧窗口
nnoremap <C-j> <C-w>j            " move to below window / 切到下方窗口
nnoremap <C-k> <C-w>k            " move to above window / 切到上方窗口
nnoremap <C-l> <C-w>l            " move to right window / 切到右侧窗口

" Visuals / 视觉效果
syntax on                        " enable syntax highlight / 启用语法高亮
set number                       " show line numbers / 显示行号
set cursorline                   " highlight current line / 高亮当前行
set cursorcolumn                 " highlight current column / 高亮当前列
set showcmd                      " show partial command / 显示命令输入
set ruler                        " show cursor position / 显示光标位置
set wildmenu                     " command-line completion menu / 命令补全菜单
set wildmode=longest:full,full   " complete to longest, then list / 先补到最长再列出
set termguicolors                " true-color support / 真彩色支持
set background=dark              " prefer dark theme / 使用深色背景

" Theme / 主题
colorscheme evening              " built-in theme / 内置主题

" UI tweaks / 界面小优化
set laststatus=2                 " always show statusline / 总是显示状态栏
set showmode                     " show mode (e.g. --INSERT--) / 显示模式
set nowrap                       " don't wrap lines / 不自动换行
set scrolloff=3                  " keep 3 lines above/below cursor / 光标上下保留3行

" Indentation / 缩进
set expandtab                    " tabs -> spaces / Tab 转空格
set shiftwidth=2                 " indent width / 缩进宽度
set tabstop=2                    " visual tab width / Tab 显示宽度
set softtabstop=2                " backspace removes 2 spaces / 退格按2空格

" Search / 搜索
set ignorecase                   " case-insensitive search / 忽略大小写
set smartcase                    " case-sensitive if uppercase / 大写时区分大小写
set incsearch                    " incremental search / 增量搜索
set hlsearch                     " highlight matches / 高亮匹配

" File handling / 文件
set hidden                       " allow switching buffers w/o save / 允许不保存切换
set updatetime=300               " faster CursorHold (ms) / 缩短触发延迟
```

- [ ] **Step 3: Verify rendered home/darwin zsh contains home proxy and excludes office proxy**

Run:

```bash
chezmoi --source . --override-data '{"role":"home"}' cat ~/.zshrc | rg -n "home macOS proxy|127.0.0.1:1088|sys-proxy-rd-relay|goproxy-token-check|vultr"
```

Expected:

- Output includes `home macOS proxy`.
- Output includes `127.0.0.1:1088`.
- Output does not include `sys-proxy-rd-relay`, `goproxy-token-check`, or `vultr`.

If `rg` exits nonzero because excluded strings are absent, rerun with separate positive and negative checks:

```bash
chezmoi --source . --override-data '{"role":"home"}' cat ~/.zshrc | rg -n "home macOS proxy|127.0.0.1:1088"
! chezmoi --source . --override-data '{"role":"home"}' cat ~/.zshrc | rg -n "sys-proxy-rd-relay|goproxy-token-check|vultr"
```

- [ ] **Step 4: Verify Vim target content**

Run:

```bash
chezmoi --source . --override-data '{"role":"home"}' cat ~/.vimrc | rg -n "Minimal, lightweight|Vim 轻量美化|set wildmenu|colorscheme evening|set smartcase"
```

Expected: all listed Vim configuration markers appear.

- [ ] **Step 5: Commit**

```bash
git add dot_zshrc.tmpl dot_vimrc
git commit -m "feat: add home macOS shell proxy and vim config"
```

## Task 5: Update Init Script and Documentation

**Files:**
- Modify: `scripts/init.sh`
- Modify: `README.md`
- Modify: `docs/machines.md`

- [ ] **Step 1: Clarify interactive role menu**

In `scripts/init.sh`, change the menu text inside `select_role()` to:

```bash
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
```

- [ ] **Step 2: Clarify final init message**

At the end of `scripts/init.sh`, replace the final log block with:

```bash
printf '\n'
case "${ROLE}" in
  home) role_description="personal macOS / Mac mini M4" ;;
  office) role_description="work macOS or office Linux cloud dev" ;;
esac
log "dotfiles deployed (role=${ROLE}, ${role_description})"
log "Restart your shell or run: exec zsh"
```

- [ ] **Step 3: Update README machine model and package list**

In `README.md`, make these content changes:

```markdown
This repository is the `chezmoi` source state for managing personal and work machines with shared defaults and role/OS-based differences.

## Machine model
- `home` + `darwin`: personal Mac mini M4 (macOS)
- `office` + `darwin`: work MacBook Pro (macOS)
- `office` + `linux`: cloud dev machine (Debian Linux)
```

Replace the design rule about machine-specific values with:

```markdown
- Put local private values in `~/.config/chezmoi/chezmoi.toml`.
- The only required local data field today is `data.role`.
```

Replace the current Homebrew tool lists with:

```markdown
Common (`brew --formula`, macOS + Linux):
- `git`
- `ripgrep`
- `eza`
- `bat`
- `zsh`
- `zoxide`
- `antidote`
- `lazygit`
- `mise`
- `d-kuro/tap/gwq`
- `jq`
- `htop`
- `zstd`
- `vim`
- `unar`
- `fzf`
- `fd`
- `aria2`
- `gh`

Common (`brew --cask`, macOS + Linux):
- `codex`
- `claude-code@latest`

macOS only (`brew --formula`):
- `cirruslabs/cli/tart`
- `wget`

macOS only (`brew --cask`):
- `visual-studio-code`
- `iterm2`
- `orbstack`
- `trae`
- `keepassxc`
```

- [ ] **Step 4: Update docs/machines.md**

Edit `docs/machines.md` to this content:

````markdown
# Machines and roles

## Role mapping
- `home` + `darwin` -> personal Mac mini M4 (macOS)
- `office` + `darwin` -> work MacBook Pro (macOS)
- `office` + `linux` -> cloud dev machine (Debian)

## Local private data location
Machine-specific private values must be stored in:
- `~/.config/chezmoi/chezmoi.toml`

## Minimum required data
```toml
[data]
role = "office" # or "home"
```

## Notes
- `machine_name` is not used as a configuration dimension.
- Use `role = "home"` for the personal Mac mini M4.
- Use `role = "office"` for work macOS and office Linux machines.
````

- [ ] **Step 5: Verify docs no longer mention stale package names**

Run:

```bash
rg -n "autojump|goenv|pyenv" README.md docs/machines.md
rg -n "machine_name" .chezmoi.toml.tmpl dot_config/chezmoi/chezmoi.toml.example
```

Expected:

- No output for `autojump`, `goenv`, or `pyenv` in README/docs.
- No output for `machine_name` in the chezmoi default or example config files.

- [ ] **Step 6: Commit**

```bash
git add scripts/init.sh README.md docs/machines.md
git commit -m "docs: clarify home Mac mini role"
```

## Task 6: Full Validation

**Files:**
- No planned file modifications unless validation exposes a defect.

- [ ] **Step 1: Check formatting and worktree state**

Run:

```bash
git diff --check
git status --short
```

Expected:

- `git diff --check` exits 0.
- `git status --short` shows no unstaged implementation changes after previous commits.

- [ ] **Step 2: Verify home/darwin template context**

Run:

```bash
chezmoi --source . --override-data '{"role":"home"}' execute-template '{{ .role }} {{ .chezmoi.os }} {{ .chezmoi.arch }}'
```

Expected on the Mac mini:

```text
home darwin arm64
```

- [ ] **Step 3: Verify home/darwin managed and ignored paths**

Run:

```bash
chezmoi --source . --override-data '{"role":"home"}' managed > /tmp/dotfiles-managed-home.txt
chezmoi --source . --override-data '{"role":"home"}' ignored > /tmp/dotfiles-ignored-home.txt
rg -n "^README.md$|^docs$|^tests$" /tmp/dotfiles-managed-home.txt
rg -n "^README.md$|^docs$|^tests$|^\\.tmux\\.conf$|^\\.local/bin/goproxy-token-check$" /tmp/dotfiles-ignored-home.txt
```

Expected:

- The first `rg` command exits nonzero because those paths are not managed.
- The second `rg` command lists `README.md`, `docs`, `tests`, `.tmux.conf`, and `.local/bin/goproxy-token-check`.

- [ ] **Step 4: Verify home/darwin target diffs render without template errors**

Run:

```bash
chezmoi --source . --override-data '{"role":"home"}' diff ~/.zshrc ~/.zshenv ~/.zsh_plugins.txt ~/.config/shell/env ~/.gitconfig ~/.vimrc ~/.profile
```

Expected: command exits 0. It may print real diffs against the current machine; it must not fail with missing `.role` or template errors.

- [ ] **Step 5: Run Linux office integration test**

Run:

```bash
tests/integration/run-linux-office.sh
```

Expected: exits 0 and prints `All Linux office integration checks passed`.

If this fails because Docker, Homebrew, network access, or sandbox permissions are unavailable, capture the failing phase and log path in the final summary. Do not remove the test expectations added in Task 1.

- [ ] **Step 6: Final status**

Run:

```bash
git status --short
git log --oneline -6
```

Expected:

- Worktree is clean.
- Recent commits include the task commits from this plan.
