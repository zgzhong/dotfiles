# Zsh: antidote + pure prompt 配置设计

> **Status:** Frozen design snapshot from 2026-04-06. Implementation has since landed and the code may have drifted from this document. Source of truth: repo source + `README.md` + `docs/machines.md`. See [`docs/superpowers/README.md`](../README.md).

## 概述

使用 antidote 作为 zsh 插件管理器，sindresorhus/pure 作为 prompt 主题，替代 powerlevel10k，保持简洁轻量。

## 变更范围

### 1. 插件列表 (`dot_zsh_plugins.txt.tmpl`)

替换当前内容为：

```
sindresorhus/pure kind:fpath
zsh-users/zsh-completions kind:fpath path:src
zsh-users/zsh-autosuggestions
zsh-users/zsh-syntax-highlighting
```

- **pure**: `kind:fpath` 仅加入 fpath，不自动 source，由 zshrc 中 `promptinit` 手动激活
- **zsh-completions**: `kind:fpath path:src` 提供补全函数文件，需加入 fpath 而非 source
- **autosuggestions**: 正常加载
- **syntax-highlighting**: 正常加载，放最后（需在其他插件之后加载）

### 2. Zsh 配置 (`dot_zshrc.tmpl`)

替换当前内容为：

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

关键设计决策：
- **compinit 在 antidote load 之后**: zsh-completions 通过 antidote 加入 fpath，compinit 需要在 fpath 完整后运行
- **promptinit 在 antidote load 之后**: pure 的 fpath 已由 antidote 设置好
- **三段式结构**: 插件加载 → 补全初始化 → prompt，后续扩展（如 codex/claude completion）直接在末尾追加

### 3. E2E 测试更新 (`tests/integration/linux-office/run-e2e.sh`)

- 插件验证断言增加 `sindresorhus/pure` 和 `zsh-users/zsh-completions`
- 交互式启动验证增加 pure prompt 已激活的检查（验证 `prompt_pure_setup` 函数存在）

## 不包含的内容

- **command-not-found**: 依赖系统包且用户环境无此文件，不纳入
- **powerlevel10k**: 不迁移任何 p10k 配置，完全替换为 pure
- **kind:defer 延迟加载**: 当前 4 个轻量插件无需优化启动速度
- **按 role 条件加载**: 所有插件为通用配置，office/home 统一加载

## 后续扩展

后续在 zshrc 末尾追加即可，不影响现有结构：
- codex/claude completion: `eval "$(codex completion zsh)"` 等
- 自定义 completion: 添加 fpath 路径或直接定义函数
