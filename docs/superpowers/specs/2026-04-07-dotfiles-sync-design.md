# Dotfiles Sync — 将 Home 目录 Dotfiles 集成到 Chezmoi 仓库

> **Status:** Frozen design snapshot from 2026-04-07. Implementation has since landed and the code may have drifted from this document. Source of truth: repo source + `README.md` + `docs/machines.md`. See [`docs/superpowers/README.md`](../README.md).

**日期**: 2026-04-07
**状态**: 设计确认

## 目标

将当前机器 home 目录下实际使用的 dotfiles 集成到 chezmoi 仓库中，使仓库成为唯一的 dotfiles 管理源。以仓库现有版本（antidote + pure）为准，把 live 环境中仓库尚未覆盖的内容补充进来。

## 设计方案

采用方案 A — 单文件模板内 if/else 条件逻辑，与仓库现有风格一致。

## 场景矩阵

| 场景 | role | OS |
|------|------|----|
| Cloud Dev | office | linux |
| MacBook Pro | office | darwin |
| Mac Mini M4 | home | darwin |

## 变更清单

### 1. 新增 `dot_gitconfig.tmpl`

- `user.name` = ZhongZegeng（共用）
- `user.email` = `zhongzegeng@bytedance.com`（office）/ `zhong550413470@gmail.com`（home）
- `url.git@code.byted.org:.insteadOf`（仅 office）
- `safe.directory = *`（共用）
- `filter.lfs`（共用）

### 2. 新增 `dot_tmux.conf`

内容不需要模板化：
- `default-terminal "tmux-256color"`
- `terminal-features ',xterm-256color:RGB'`
- `mouse on`
- `focus-events on`

通过 `.chezmoiignore` 限制为 office + linux 才部署。

### 3. 新增 `.chezmoiignore`

```
{{ if not (and (eq .role "office") (eq .chezmoi.os "linux")) }}
.tmux.conf
{{ end }}
```

### 4. 修改 `dot_zshenv.tmpl`

在 Homebrew shellenv 之后追加：

- Rust 环境变量（所有场景）：
  - `RUSTUP_DIST_SERVER` / `RUSTUP_UPDATE_ROOT`（rsproxy.cn 镜像）
  - `[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"`
- `$HOME/.local/bin` 加入 PATH（仅 office + linux）

### 5. 修改 `dot_zsh_plugins.txt.tmpl`

追加 fzf-tab 插件：
```
Aloxaf/fzf-tab
```

### 6. 修改 `dot_zshrc.tmpl`

在现有结构基础上追加以下 section（按顺序）：

#### 6a. fzf 集成（所有场景）

在 completions 之后、aliases 之前：
```bash
[[ -f "$(brew --prefix fzf)/shell/key-bindings.zsh" ]] && source "$(brew --prefix fzf)/shell/key-bindings.zsh"
[[ -f "$(brew --prefix fzf)/shell/completion.zsh" ]] && source "$(brew --prefix fzf)/shell/completion.zsh"
```

提供 Ctrl+R（历史搜索）、Ctrl+T（文件搜索）、Alt+C（目录跳转）。fzf-tab 通过 antidote 插件加载，提供全面的 Tab 补全 fzf 化。

#### 6b. codex/claude 代理函数（所有场景）

使用 chezmoi 变量定义代理地址：
- office + linux: `http://127.0.0.1:20170`
- 其余场景: `http://127.0.0.1:1088`

生成 `codex()` 和 `claude()` wrapper 函数，设置 `HTTP_PROXY`/`HTTPS_PROXY`/`http_proxy`/`https_proxy`，调用 `${HOMEBREW_PREFIX}/bin/codex` / `${HOMEBREW_PREFIX}/bin/claude`。

#### 6c. 系统 PATH（仅 office + linux）

```bash
export PATH=/opt/tiger/ss_bin:$PATH
export PATH=/opt/tiger/typhoon-blade:$PATH
```

#### 6d. codex 补全（所有场景）

```bash
source <(codex completion zsh)
```

放在 gwq completion 旁边。

### 7. 新增 `run_once_before_25-install-rust.sh.tmpl`

编号 25，在 Homebrew（20）之后、dev tools（30）之前：
- 设置 Rust 镜像环境变量
- office + linux 场景设代理
- `curl ... https://sh.rustup.rs | sh -s -- -y` 非交互安装

### 8. 修改 `run_onchange_after_30-install-dev-tools.sh.tmpl`

- 共用 formulae 追加 `fzf`
- 共用 casks 追加 `claude`

## 不做的事

- fzf 独立配置文件（`.fzf.zsh`）— 集成到 zshrc 中
- mise config 同步 — 后续再做
- 全局 gitignore — 后续再做
- CloudIDE 集成 — 文件不存在，跳过
- bashrc 管理 — 非主力 shell，不纳入
- docker-compose 代理服务 — 后续再考虑
- `.profile` 中 cargo/env 加载 — 已迁移到 `.zshenv`

## E2E 测试更新

需要在 `tests/integration/linux-office/run-e2e.sh` 中追加断言：

- `.gitconfig` 存在且包含 office email、URL 重写、LFS
- `.tmux.conf` 存在且包含预期内容
- `.zshenv` 包含 Rust 镜像变量和 cargo/env 加载、`~/.local/bin`
- `.zshrc` 包含 fzf 集成、codex/claude 代理函数（20170 端口）、系统 PATH、codex 补全
- `.zsh_plugins.txt` 包含 fzf-tab
- Rust 工具链已安装（`rustc --version`）
