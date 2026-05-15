# Goproxy Setup Implementation Plan

> **Status:** Frozen design snapshot from 2026-04-09. Implementation has since landed and the code may have drifted from this document. Source of truth: repo source + `README.md` + `docs/machines.md`. See [`docs/superpowers/README.md`](../README.md).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install goproxy_setup_cli, configure Go proxy env vars via mise-managed Go, and auto-check JWT token expiry on interactive shell startup (office only).

**Architecture:** A new chezmoi `run_onchange_after` script (35) installs Go 1.24 via mise, downloads goproxy_setup_cli, and runs `go env -w` to persist proxy settings. The token-check logic lives in a standalone script `~/.local/bin/goproxy-token-check` (managed by chezmoi, office-only via `.chezmoiignore`), and the zshrc calls it with a single line. The `~/.local/bin` PATH is extended from office+linux to all office roles so both CLIs are reachable on macOS too.

**Tech Stack:** chezmoi (Go text/template), bash (run scripts + token check script), zsh (shell config), mise (Go SDK), JWT (base64url + jq)

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `dot_zshenv.tmpl` | Extend `~/.local/bin` PATH to all office roles |
| Create | `run_onchange_after_35-setup-go-and-goproxy.sh.tmpl` | Install Go via mise, download goproxy_setup_cli, run `go env -w` |
| Create | `private_dot_local/private_bin/executable_goproxy-token-check` | Standalone script: parse ~/.netrc JWT, prompt SSO renewal |
| Modify | `.chezmoiignore` | Exclude goproxy-token-check for non-office roles |
| Modify | `dot_zshrc.tmpl` | One-liner to call goproxy-token-check (office only) |
| Modify | `tests/integration/linux-office/run-e2e.sh` | Add assertions for Go, go env, token check script |

---

### Task 1: Extend ~/.local/bin PATH to all office roles

**Files:**
- Modify: `dot_zshenv.tmpl:31-34`

Currently `~/.local/bin` is only added to PATH for `office+linux`. The goproxy_setup_cli binary lives in `~/.local/bin` and must be reachable on macOS too. Change the condition from `office+linux` to `office`.

- [ ] **Step 1: Edit dot_zshenv.tmpl**

Change lines 31-34 from:

```
{{ if and (eq .role "office") (eq .chezmoi.os "linux") -}}
# local bin
export PATH="$HOME/.local/bin:$PATH"
{{- end }}
```

To:

```
{{ if eq .role "office" -}}
# local bin
export PATH="$HOME/.local/bin:$PATH"
{{- end }}
```

- [ ] **Step 2: Verify template renders correctly**

Run:

```bash
cd /data00/home/zhongzegeng/src/dotfiles
chezmoi execute-template < dot_zshenv.tmpl
```

Expected: output includes `export PATH="$HOME/.local/bin:$PATH"` without the linux guard.

- [ ] **Step 3: Commit**

```bash
git add dot_zshenv.tmpl
git commit -m "feat: extend ~/.local/bin PATH to all office roles"
```

---

### Task 2: Create the Go + goproxy install script

**Files:**
- Create: `run_onchange_after_35-setup-go-and-goproxy.sh.tmpl`

This script runs after script 30 (which installs mise via brew). It:
1. Skips entirely for non-office roles
2. Resolves brew shellenv so mise is in PATH
3. Installs Go 1.24 globally via `mise use -g go@1.24`
4. Creates `~/.local/bin` and downloads goproxy_setup_cli (failure is non-fatal)
5. Runs `go env -w` to persist GOPRIVATE/GOPROXY/GONOSUMDB/GONOPROXY

- [ ] **Step 1: Create the script**

Create `run_onchange_after_35-setup-go-and-goproxy.sh.tmpl` with the following content:

```bash
#!/usr/bin/env bash
set -euo pipefail

{{ template "brew-lib.sh.tmpl" . }}
{{ template "proxy-lib.sh.tmpl" . }}

os="{{ .chezmoi.os }}"
role="{{ .role | default "" }}"

if [[ "$role" != "office" ]]; then
  echo "[chezmoi] goproxy setup is office-only, skipping"
  exit 0
fi

setup_office_linux_proxy "$os" "$role"

if ! resolve_brew_shellenv "$os"; then
  echo "[chezmoi] brew not found, cannot proceed" >&2
  exit 1
fi

# --- Install Go via mise ---
if ! command -v mise >/dev/null 2>&1; then
  echo "[chezmoi] mise not found, cannot install Go" >&2
  exit 1
fi

echo "[chezmoi] Installing Go 1.24 via mise..."
mise use -g go@1.24
eval "$(mise activate bash)"

if ! command -v go >/dev/null 2>&1; then
  echo "[chezmoi] go not found after mise install" >&2
  exit 1
fi
echo "[chezmoi] Go version: $(go version)"

# --- Download goproxy_setup_cli ---
mkdir -p "$HOME/.local/bin"
GOPROXY_CLI="$HOME/.local/bin/goproxy_setup_cli"

if [[ ! -x "$GOPROXY_CLI" ]]; then
  {{ if eq .chezmoi.os "linux" -}}
  GOPROXY_URL="https://luban-source.byted.org/repository/asset/test/goproxy_setup_cli/goproxy_setup_cli_linux_amd64"
  {{ else if eq .chezmoi.os "darwin" -}}
  GOPROXY_URL="https://luban-source.byted.org/repository/asset/test/goproxy_setup_cli/goproxy_setup_cli_darwin_arm64"
  {{ end -}}
  echo "[chezmoi] Downloading goproxy_setup_cli..."
  if curl -fsSL "$GOPROXY_URL" -o "$GOPROXY_CLI"; then
    chmod +x "$GOPROXY_CLI"
    echo "[chezmoi] goproxy_setup_cli installed to $GOPROXY_CLI"
  else
    echo "[chezmoi] Warning: Could not download goproxy_setup_cli (network issue?), skipping"
    rm -f "$GOPROXY_CLI"
  fi
else
  echo "[chezmoi] goproxy_setup_cli already installed"
fi

# --- Configure Go proxy ---
echo "[chezmoi] Configuring Go proxy environment..."
go env -w \
  GOPRIVATE="gitlab.everphoto.cn,sysrepo.byted.org" \
  GONOSUMDB='*.byted.org' \
  GOPROXY='https://goproxy.byted.org|direct' \
  GONOPROXY='gitlab.everphoto.cn,sysrepo.byted.org'

echo "[chezmoi] Go proxy setup complete"
```

- [ ] **Step 2: Verify the template renders without syntax errors**

Run:

```bash
cd /data00/home/zhongzegeng/src/dotfiles
chezmoi execute-template < run_onchange_after_35-setup-go-and-goproxy.sh.tmpl
```

Expected: a valid bash script with the correct OS-specific download URL rendered.

- [ ] **Step 3: Commit**

```bash
git add run_onchange_after_35-setup-go-and-goproxy.sh.tmpl
git commit -m "feat: add run script to install Go via mise and configure goproxy"
```

---

### Task 3: Create standalone goproxy-token-check script

**Files:**
- Create: `private_dot_local/private_bin/executable_goproxy-token-check`
- Modify: `.chezmoiignore`

Extract the token check logic into a standalone bash script managed by chezmoi. This script:
1. Checks if `goproxy_setup_cli` exists in the same directory — silently exits if not
2. Reads `~/.netrc` for the `goproxy.byted.org` machine entry
3. If no entry found, prompts user to SSO login with `[Y/n]`
4. If entry found, decodes JWT payload (base64url), extracts `exp` timestamp via `jq`
5. If token expires within 10 days or already expired, prints expiry info and asks `[Y/n]`
6. Uses portable base64 decoding (`base64 -d` || `base64 -D`) and date formatting (`date -d` || `date -r`)

The file is excluded for non-office roles via `.chezmoiignore`.

**Chezmoi path mapping:**
- Source: `private_dot_local/private_bin/executable_goproxy-token-check`
- Target: `~/.local/bin/goproxy-token-check` (mode 0755 due to `executable_` prefix)

- [ ] **Step 1: Create the directory structure**

```bash
mkdir -p /data00/home/zhongzegeng/src/dotfiles/private_dot_local/private_bin
```

- [ ] **Step 2: Create the script**

Create `private_dot_local/private_bin/executable_goproxy-token-check` with the following content:

```bash
#!/usr/bin/env bash
# Goproxy JWT token check — prompts SSO renewal when token is missing or near expiry.
# Called from ~/.zshrc on interactive shell startup (office only).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="${SCRIPT_DIR}/goproxy_setup_cli"

# Silently skip if goproxy_setup_cli is not installed
[[ -x "$CLI" ]] || exit 0

NETRC="$HOME/.netrc"
TOKEN=""

if [[ -f "$NETRC" ]]; then
  TOKEN=$(awk '/machine goproxy\.byted\.org/{found=1} found && /password/{print $2; exit}' "$NETRC")
fi

prompt_login() {
  local message="$1"
  echo "$message"
  printf "[goproxy] Run SSO login now? [Y/n] "
  read -r reply </dev/tty
  if [[ "$reply" =~ ^[Nn] ]]; then
    exit 0
  fi
  "$CLI" login
}

if [[ -z "$TOKEN" ]]; then
  prompt_login "[goproxy] No token found for goproxy.byted.org"
  exit 0
fi

# Decode JWT payload (base64url -> base64 -> json)
B64=$(echo "$TOKEN" | cut -d. -f2)
case $(( ${#B64} % 4 )) in
  2) B64="${B64}==" ;;
  3) B64="${B64}=" ;;
esac
PAYLOAD=$(echo "$B64" | tr '_-' '/+' | { base64 -d 2>/dev/null || base64 -D 2>/dev/null; })
EXP_TS=$(echo "$PAYLOAD" | jq -r '.exp' 2>/dev/null)

if [[ -z "$EXP_TS" || "$EXP_TS" == "null" ]]; then
  prompt_login "[goproxy] Cannot parse token"
  exit 0
fi

NOW=$(date +%s)
DAYS_LEFT=$(( (EXP_TS - NOW) / 86400 ))

if (( DAYS_LEFT <= 10 )); then
  EXP_DATE=$(date -d "@$EXP_TS" '+%Y-%m-%d' 2>/dev/null || date -r "$EXP_TS" '+%Y-%m-%d' 2>/dev/null)
  if (( DAYS_LEFT > 0 )); then
    prompt_login "[goproxy] Token expires on ${EXP_DATE} (${DAYS_LEFT} days left)"
  else
    prompt_login "[goproxy] Token has expired (was ${EXP_DATE})"
  fi
fi
```

- [ ] **Step 3: Update .chezmoiignore to exclude for non-office roles**

The current `.chezmoiignore` is:

```
{{ if not (and (eq .role "office") (eq .chezmoi.os "linux")) }}
.tmux.conf
{{ end }}
```

Change it to:

```
{{ if not (and (eq .role "office") (eq .chezmoi.os "linux")) }}
.tmux.conf
{{ end }}
{{ if ne .role "office" }}
.local/bin/goproxy-token-check
{{ end }}
```

- [ ] **Step 4: Verify chezmoi sees the new file**

Run:

```bash
cd /data00/home/zhongzegeng/src/dotfiles
chezmoi managed | grep goproxy
```

Expected: `.local/bin/goproxy-token-check` appears in the output.

- [ ] **Step 5: Commit**

```bash
git add private_dot_local/private_bin/executable_goproxy-token-check .chezmoiignore
git commit -m "feat: add standalone goproxy-token-check script (office only)"
```

---

### Task 4: Add one-liner call in zshrc

**Files:**
- Modify: `dot_zshrc.tmpl` (insert before `# --- codex completion ---`, after the AI tools section)

Replace the inline function approach with a single line that calls the standalone script.

- [ ] **Step 1: Add the one-liner to dot_zshrc.tmpl**

Insert the following block **before** the `# --- codex completion ---` section (before line 118 in current file):

```
{{ if eq .role "office" -}}
# --- goproxy token auto-renewal ---
[[ -x "$HOME/.local/bin/goproxy-token-check" ]] && "$HOME/.local/bin/goproxy-token-check"
{{- end }}
```

- [ ] **Step 2: Verify template renders correctly**

Run:

```bash
cd /data00/home/zhongzegeng/src/dotfiles
chezmoi execute-template < dot_zshrc.tmpl
```

Expected: output includes `[[ -x "$HOME/.local/bin/goproxy-token-check" ]] && "$HOME/.local/bin/goproxy-token-check"`.

- [ ] **Step 3: Commit**

```bash
git add dot_zshrc.tmpl
git commit -m "feat: call goproxy-token-check from zshrc (office only)"
```

---

### Task 5: Update E2E tests

**Files:**
- Modify: `tests/integration/linux-office/run-e2e.sh`

Add validation phases for:
1. Go installation via mise — verify `go version` works after activating mise
2. Go proxy env — verify `go env GOPROXY` contains `goproxy.byted.org`
3. Rendered file assertions — verify goproxy-token-check script deployed and zshrc calls it
4. zshenv PATH — verify `.local/bin` assertion still passes (already present)

Note: Do NOT assert goproxy_setup_cli binary exists (internal URL may fail in Docker).

- [ ] **Step 1: Add Go validation phase after the rust validation phase**

Insert after the `validate rust installation` phase (after line 151), before `phase "validate rendered files"`:

```bash
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
```

- [ ] **Step 2: Add rendered file assertions for goproxy**

Insert after the existing `assert_file_contains "$HOME/.zshrc" 'zoxide init zsh'` line (line 203):

```bash
assert_file_contains "$HOME/.zshrc" 'goproxy-token-check'
assert_file_exists "$HOME/.local/bin/goproxy-token-check"
assert_file_contains "$HOME/.local/bin/goproxy-token-check" 'goproxy.byted.org'
assert_file_contains "$HOME/.local/bin/goproxy-token-check" 'goproxy_setup_cli'
assert_file_contains "$HOME/.local/bin/goproxy-token-check" 'Renew now?'
```

- [ ] **Step 3: Commit**

```bash
git add tests/integration/linux-office/run-e2e.sh
git commit -m "test: add E2E assertions for Go/goproxy setup and token check"
```

---

### Task 6: Run E2E tests

- [ ] **Step 1: Build and run the Docker-based integration test**

```bash
cd /data00/home/zhongzegeng/src/dotfiles
docker build -t dotfiles-test -f tests/integration/linux-office/Dockerfile .
docker run --rm dotfiles-test
```

Expected: all phases pass including new Go, goproxy, and token check assertions.

- [ ] **Step 2: If tests fail, review the log output and fix issues**

Check the specific phase that failed and adjust the corresponding file.

- [ ] **Step 3: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address E2E test failures for goproxy setup"
```
