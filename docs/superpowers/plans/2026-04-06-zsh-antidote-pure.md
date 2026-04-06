# Zsh antidote + pure prompt 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 配置 antidote 插件管理器加载 pure prompt 和常用 zsh 插件，并更新 E2E 测试覆盖。

**Architecture:** 三个文件变更：插件列表声明插件、zshrc 按正确顺序加载（antidote → compinit → promptinit）、E2E 测试验证渲染内容和交互式启动。

**Tech Stack:** chezmoi templates, antidote, zsh, bash (tests)

***

### File Map

| File                                        | Action | Responsibility           |
| ------------------------------------------- | ------ | ------------------------ |
| `dot_zsh_plugins.txt.tmpl`                  | Modify | 声明所有 antidote 插件         |
| `dot_zshrc.tmpl`                            | Modify | 加载顺序调整 + pure prompt 初始化 |
| `tests/integration/linux-office/run-e2e.sh` | Modify | 新增插件和 prompt 断言          |

***

### Task 1: 更新插件列表

**Files:**

- Modify: `dot_zsh_plugins.txt.tmpl`
- [ ] **Step 1: 替换插件列表内容**

将 `dot_zsh_plugins.txt.tmpl` 的全部内容替换为：

```
sindresorhus/pure kind:fpath
zsh-users/zsh-completions kind:fpath path:src
zsh-users/zsh-autosuggestions
zsh-users/zsh-syntax-highlighting
```

- [ ] **Step 2: 验证文件内容**

Run: `cat dot_zsh_plugins.txt.tmpl`

Expected: 4 行，pure 在最前，syntax-highlighting 在最后。

- [ ] **Step 3: Commit**

```bash
git add dot_zsh_plugins.txt.tmpl
git commit -m "feat(zsh): add pure prompt and zsh-completions to plugin list"
```

***

### Task 2: 更新 zshrc 配置

**Files:**

- Modify: `dot_zshrc.tmpl`
- [ ] **Step 1: 替换 zshrc 内容**

将 `dot_zshrc.tmpl` 的全部内容替换为：

```bash
# shellcheck shell=zsh
# Managed by chezmoi. Interactive zsh configuration.

[[ -o interactive ]] || return 0

# Load chezmoi-managed environment variables (DOTFILES_ROLE, DOTFILES_OS, etc.)
if [[ -f "$HOME/.config/shell/env" ]]; then
  . "$HOME/.config/shell/env"
fi

# --- antidote plugin manager ---
if command -v brew >/dev/null 2>&1; then
  antidote_file="$(brew --prefix antidote 2>/dev/null)/share/antidote/antidote.zsh"
  if [[ -f "$antidote_file" ]]; then
    . "$antidote_file"
    antidote load "$HOME/.zsh_plugins.txt"
  fi
fi

# --- completions ---
autoload -Uz compinit
compinit -u

# --- pure prompt ---
autoload -Uz promptinit
promptinit
prompt pure
```

关键变更：

- antidote load 移到 compinit 之前（zsh-completions 需要先加入 fpath）
- 新增 promptinit + prompt pure 区块
- 新增注释说明 chezmoi env 文件用途
- [ ] **Step 2: 验证文件结构**

Run: `head -30 dot_zshrc.tmpl`

Expected: 三段式结构——antidote → compinit → pure prompt。compinit 在 antidote load 之后。

- [ ] **Step 3: Commit**

```bash
git add dot_zshrc.tmpl
git commit -m "feat(zsh): reorder loading and add pure prompt initialization"
```

***

### Task 3: 更新 E2E 测试 — 渲染文件断言

**Files:**

- Modify: `tests/integration/linux-office/run-e2e.sh:136-148`
- [ ] **Step 1: 在 "validate rendered files" phase 中添加新断言**

在 `run-e2e.sh` 的 `assert_file_contains "$HOME/.zsh_plugins.txt" 'zsh-users/zsh-syntax-highlighting'` 行（第 148 行）之后，添加：

```bash
assert_file_contains "$HOME/.zsh_plugins.txt" 'sindresorhus/pure'
assert_file_contains "$HOME/.zsh_plugins.txt" 'zsh-users/zsh-completions'
assert_file_contains "$HOME/.zshrc" 'prompt pure'
```

- [ ] **Step 2: 验证断言位置**

Run: `rg -n 'assert_file_contains.*zsh_plugins\|assert_file_contains.*zshrc' tests/integration/linux-office/run-e2e.sh`

Expected: 能看到原有的 autosuggestions、syntax-highlighting 断言，加上新增的 pure、zsh-completions、prompt pure 断言。

- [ ] **Step 3: Commit**

```bash
git add tests/integration/linux-office/run-e2e.sh
git commit -m "test: add rendered file assertions for pure and zsh-completions"
```

***

### Task 4: 更新 E2E 测试 — 交互式启动验证

**Files:**

- Modify: `tests/integration/linux-office/run-e2e.sh:153-154`
- [ ] **Step 1: 扩展 "validate zsh startup" phase 的 smoke test**

将第 154 行：

```bash
run_step "zsh-smoke" zsh -ic 'command -v antidote >/dev/null && [[ -n "${DOTFILES_ROLE:-}" ]] && [[ -n "${DOTFILES_OS:-}" ]]'
```

替换为：

```bash
run_step "zsh-smoke" zsh -ic 'command -v antidote >/dev/null && [[ -n "${DOTFILES_ROLE:-}" ]] && [[ -n "${DOTFILES_OS:-}" ]] && (( ${+functions[prompt_pure_setup]} ))'
```

新增的 `(( ${+functions[prompt_pure_setup]} ))` 验证 pure prompt 的 setup 函数已被加载，说明 prompt 初始化成功。

- [ ] **Step 2: 验证修改**

Run: `rg -n 'prompt_pure_setup' tests/integration/linux-office/run-e2e.sh`

Expected: 在 zsh-smoke 行中能看到 `prompt_pure_setup`。

- [ ] **Step 3: Commit**

```bash
git add tests/integration/linux-office/run-e2e.sh
git commit -m "test: verify pure prompt loads in interactive zsh startup"
```

