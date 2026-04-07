# Replace pyenv/goenv with mise & sync aliases

## Goal

1. Replace `pyenv` and `goenv` with `mise` as the unified language SDK manager.
2. Sync aliases and shell config from the live `~/.zshrc` into chezmoi-managed `dot_zshrc.tmpl`, with role-based conditional blocks for office-specific settings.

## Scope

### Files changed

| File | Change |
|------|--------|
| `run_onchange_after_30-install-dev-tools.sh.tmpl` | Remove `goenv`/`pyenv` from `common_formulae`, add `mise` |
| `dot_zshrc.tmpl` | Append alias, env, proxy, mise activation, PATH, and gwq completion blocks |

### Files NOT changed

- `dot_zshenv.tmpl`
- `dot_profile.tmpl`
- `dot_zsh_plugins.txt.tmpl`
- `dot_config/shell/env.tmpl`

## Design

### 1. Brew formulae update (`run_onchange_after_30-install-dev-tools.sh.tmpl`)

In `common_formulae` array:
- Remove: `goenv`, `pyenv`
- Add: `mise`

### 2. Shell config additions (`dot_zshrc.tmpl`)

All new content is appended after the existing `prompt pure` line. Order:

#### 2.1 Common aliases

```zsh
alias cls='clear'
alias ls='eza -FTh -s type -L1'
alias ll='ls -l'
alias sl='ls'
alias la='ls -a'
alias grep="rg --color=auto -glob='!.{.bzr,git,hg,idea,vscode}'"
alias gerp='grep'
alias lg='lazygit'
alias vi='vim'
```

#### 2.2 Office-only aliases (conditional on `role == "office"`)

```zsh
alias s='ssh -K zhongzegeng@BYTEDANCE.COM'
alias k='kinit --keychain zhongzegeng@BYTEDANCE.COM'
```

#### 2.3 Environment variables (common)

```zsh
export LC_TIME="en_US.UTF-8"
export EDITOR=vim
```

#### 2.4 Office proxy (conditional on `role == "office"`)

```zsh
export no_proxy="localhost,.byted.org,byted.org,.bytedance.net,bytedance.net,.byteintl.net,byteintl.net,127.0.0.1,127.0.0.0/8,169.254.0.0/16,100.64.0.0/10,172.16.0.0/12,192.168.0.0/16,10.0.0.0/8,::1,fe80::/10,fd00::/8"

set_proxy() {
  export http_proxy=http://sys-proxy-rd-relay.byted.org:8118 \
         https_proxy=http://sys-proxy-rd-relay.byted.org:8118
}

unset_proxy() {
  unset http_proxy https_proxy no_proxy
}
```

#### 2.5 mise activation (with guard)

```zsh
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
```

#### 2.6 PATH additions

```zsh
export PATH="$GOROOT/bin:$PATH"
export PATH="$PATH:$GOPATH/bin"
```

#### 2.7 gwq completion (with guard)

```zsh
if command -v gwq >/dev/null 2>&1; then
  source <(gwq completion zsh)
fi
```

### Order within `dot_zshrc.tmpl`

1. Interactive guard
2. Load chezmoi env
3. Antidote plugin manager
4. Completions (`compinit`)
5. Pure prompt
6. **Common aliases** (new)
7. **Office-only aliases** (new, conditional)
8. **Environment variables** (new)
9. **Office proxy** (new, conditional)
10. **mise activation** (new)
11. **PATH** (new)
12. **gwq completion** (new) - must be after `compinit`

## Not included (deferred)

- Rust environment (`RUSTUP_DIST_SERVER`, cargo env)
- ByteDance internal paths (`/opt/tiger/...`)
- CloudIDE config
- Codex/Claude wrapper functions (office proxy-dependent)
