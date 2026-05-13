# Mac mini M4 home/darwin dotfiles design

## Goal

Adjust this chezmoi dotfiles repository so the current Mac mini M4 can be represented cleanly as the personal home macOS machine. The repository changes should make a future bootstrap/init produce the intended `home + darwin` target state, without migrating the current local machine during this design/implementation cycle.

## Confirmed scope

- Manage CLI dotfiles and Homebrew-installed GUI apps.
- Do not manage macOS defaults, App Store apps, fonts, LaunchAgents, login items, SSH keys, password databases, browser data, or other sensitive/private state.
- Do not migrate the current machine's `~/.config/chezmoi/chezmoi.toml` or chezmoi source path in this work.
- Keep sensitive host details out of the public repository.

## Machine model

Continue using the existing `role + OS` model:

```toml
[data]
role = "home"
```

For this repository, `home + darwin` represents the current Mac mini M4 personal machine. Do not introduce `machine_name` as a supported configuration dimension, because the confirmed changes can be expressed with existing `common` and `darwin` layers.

Changes:

- Remove `machine_name` from `.chezmoi.toml.tmpl`.
- Remove `machine_name` from `dot_config/chezmoi/chezmoi.toml.example`.
- Keep `scripts/init.sh` generating only `role`.
- Update `scripts/init.sh` prompts and completion text so `home` is clearly described as the personal macOS/Mac mini path, while `office` remains the work/cloud path.
- Update `README.md` and `docs/machines.md` to describe the model consistently and fix the README machine list ambiguity.

## Homebrew package management

Keep the existing package structure in `run_onchange_after_30-install-dev-tools.sh.tmpl`:

- `common_formulae`
- `common_casks`
- `macos_formulae`
- `macos_casks`

Do not migrate to Brewfile, and do not add `home_darwin` or machine-specific arrays.

Add:

- `common_formulae`: `aria2`, `gh`
- `macos_formulae`: `cirruslabs/cli/tart`, `wget`
- `macos_casks`: `keepassxc`

Keep all existing managed packages even if the current Mac mini does not have them installed yet:

- Formulae: `git`, `bat`, `zoxide`, `antidote`, `mise`, `d-kuro/tap/gwq`, `jq`, `vim`, `fzf`, `fd`
- Casks: `claude-code@latest`, `iterm2`, `trae`

Do not add:

- `antigen`
- `autojump`
- `goenv`
- `pyenv`
- `krb5`
- `android-platform-tools`

Update README's package list to match the actual install script. In particular, remove stale references to `autojump`, `goenv`, and `pyenv`, and include current tools such as `zoxide`, `mise`, `gwq`, `fzf`, `fd`, and `claude-code@latest`.

## Shell configuration

Use the repository's current shell stack as the target for Mac mini:

- Use `antidote` for zsh plugins.
- Use `pure` for prompt.
- Use `zoxide` instead of `autojump`.
- Use `mise` instead of `goenv`/`pyenv`.
- Keep `fzf`/`fd` integration.
- Keep Rust initialization in `.zshenv`, including `rsproxy.cn` Rust mirrors.
- Let chezmoi create `.zshenv`, `.zsh_plugins.txt`, and `.config/shell/env` on Mac mini.

Do not migrate these live `.zshrc` items:

- Powerlevel10k instant prompt and theme.
- `antigen` setup.
- `autojump`, `goenv`, and `pyenv` initialization.
- `alias vultr="ssh -p 7418 zgzhong@zgzhong.xyz"` because it exposes private host details.
- Homebrew `FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"`.

Add a home/darwin terminal proxy helper using the same local proxy port as the existing home/darwin AI wrappers:

```zsh
set_proxy() {
  export http_proxy=http://127.0.0.1:1088
  export https_proxy=http://127.0.0.1:1088
}

unset_proxy() {
  unset http_proxy https_proxy
}
```

This helper must be scoped to `role == "home"` and `os == "darwin"`.

## Vim, Git, and profile files

Replace `dot_vimrc` with the live Mac mini `.vimrc` style as the source of truth:

- Lightweight Vim configuration with no plugins.
- Clear sections.
- English + Chinese bilingual comments.
- Keep live functionality such as leader mappings, window navigation mappings, line numbers, syntax highlighting, dark background, cursorline/cursorcolumn, nowrap, and search highlighting.

Use the existing repository `.gitconfig` target for Mac mini:

- `user.name = ZhongZegeng`
- `user.email = zhong550413470@gmail.com`
- `safe.directory = *`
- Git LFS filter settings

Use the existing repository `.profile` target:

- POSIX shell Homebrew shellenv only.
- Do not source Rust cargo env from `.profile`; Rust remains in `.zshenv`.

## Chezmoi ignore rules

Update `.chezmoiignore` so repository maintenance files are not deployed to `$HOME`:

```text
README.md
docs/
tests/
```

Keep existing ignore behavior:

- `.tmux.conf` is deployed only for `office + linux`.
- `.local/bin/goproxy-token-check` is deployed only for `office`.
- `scripts/` is not deployed.

## Documentation updates

Update docs to make these facts explicit:

- The current Mac mini M4 is represented by `role = "home"` on `darwin`.
- No `machine_name` field is required or supported for current configuration branching.
- `home` is personal; `office` is work/cloud.
- Homebrew package lists in README match the install script.
- Bootstrap/init asks for role only; later local bootstrap/init is responsible for writing the real local chezmoi config.

## Validation

Implementation should verify template rendering and managed paths without mutating the current machine:

```sh
chezmoi --source . --override-data '{"role":"home"}' execute-template '{{ .role }} {{ .chezmoi.os }} {{ .chezmoi.arch }}'
chezmoi --source . --override-data '{"role":"home"}' managed
chezmoi --source . --override-data '{"role":"home"}' ignored
chezmoi --source . --override-data '{"role":"home"}' diff ~/.zshrc ~/.zshenv ~/.zsh_plugins.txt ~/.config/shell/env ~/.gitconfig ~/.vimrc ~/.profile
```

Expected checks:

- Rendered context includes `home darwin arm64` on the Mac mini.
- `README.md`, `docs/`, and `tests/` do not appear in managed targets.
- Mac mini target files still appear in managed targets.
- `.tmux.conf` and `goproxy-token-check` remain ignored for `home + darwin`.
- Templates do not fail with missing `.role`.

Attempt the existing Linux office integration test after template-level validation:

```sh
tests/integration/run-linux-office.sh
```

Update Linux office test assertions for newly added common formulae (`aria2`, `gh`) if the test already asserts the full common formula set. If the integration test cannot complete because of sandbox, network, or host dependency constraints, record the exact failure and rely on the template-level checks for this implementation pass. Do not add a full macOS e2e test unless a maintained macOS runner pattern already exists.

## Out of scope

- Writing or migrating the current machine's real `~/.config/chezmoi/chezmoi.toml`.
- Moving the current chezmoi source directory.
- Managing private SSH host aliases.
- Managing password database files or secrets.
- Managing macOS defaults or GUI settings outside Homebrew casks.
