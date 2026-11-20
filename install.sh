#!/usr/bin/env bash
# Bootstrap: install CLI tools into ~/.local (no root needed), link configs,
# and hook shell/init.sh into bash and zsh. Safe to re-run.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
OPT="$HOME/.local/opt"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

DEFAULT_GIT_EMAIL="kaarelkivistik@gmail.com"

# Pinned release tags. To upgrade a tool, bump its tag here and re-run
# install.sh: tools whose pin changed are reinstalled. tmux-resurrect is
# pinned in tmux/tmux.conf and lazy.nvim/plugins in nvim/lazy-lock.json.
EGET_VERSION=v1.3.4
NVIM_VERSION=v0.12.6
FZF_VERSION=v0.75.0
ZOXIDE_VERSION=v0.10.0
FD_VERSION=v10.5.2
BAT_VERSION=v0.26.1
RG_VERSION=15.2.0
LAZYGIT_VERSION=v0.66.3
YAZI_VERSION=v26.9.1
DELTA_VERSION=0.20.1
STARSHIP_VERSION=v1.27.0
JQ_VERSION=jq-1.8.2
YQ_VERSION=v4.54.3
EZA_VERSION=v0.23.5
TPM_VERSION=v3.1.0

UPDATE=0
GIT_EMAIL=""
DO_TOOLS=1
DO_LINKS=1
DO_SHELL=1

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<EOF
Usage: $0 [options]

  -u, --update     Reinstall tools and tmux plugins at their pinned versions,
                   even if already installed
  --git-email ADDR Git e-mail to use without prompting (default: $DEFAULT_GIT_EMAIL)
  --no-tools       Skip installing tools
  --no-links       Skip symlinking config files
  --no-shell       Skip editing ~/.bashrc / ~/.zshrc
  -h, --help       Show this help

Set GITHUB_TOKEN to avoid GitHub API rate limits (60 requests/hour unauthenticated).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -u|--update) UPDATE=1 ;;
    --git-email)
      [ $# -ge 2 ] || die "--git-email needs an address"
      GIT_EMAIL="$2"; shift ;;
    --no-tools) DO_TOOLS=0 ;;
    --no-links) DO_LINKS=0 ;;
    --no-shell) DO_SHELL=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

OS="$(uname -s)"
case "$OS" in
  Linux|Darwin) ;;
  *) die "Unsupported OS: $OS" ;;
esac

# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------

# Each installed tool gets a stamp file holding the tag it was installed at,
# so a bumped pin triggers a reinstall.
STAMPS="$OPT/versions"

# needs_install <name> <file> <version>: true if <file> is missing, was
# installed at a different version, or --update was given.
needs_install() {
  [ "$UPDATE" = 1 ] || [ ! -x "$2" ] ||
    [ "$(cat "$STAMPS/$1" 2>/dev/null)" != "$3" ]
}

stamp() {
  mkdir -p "$STAMPS"
  echo "$2" > "$STAMPS/$1"
}

# eget_platform: eget's release asset suffix for this machine.
eget_platform() {
  local os arch
  os="$(echo "$OS" | tr '[:upper:]' '[:lower:]')"
  case "$(uname -m)" in
    arm64|aarch64) arch=arm64 ;;
    arm*)          arch=arm ;;
    x86_64|amd64)  arch=amd64 ;;
    i?86)          arch=386 ;;
    *) die "Unsupported architecture for eget: $(uname -m)" ;;
  esac
  echo "${os}_${arch}"
}

install_eget() {
  needs_install eget "$BIN/eget" "$EGET_VERSION" || return 0
  log "Installing eget $EGET_VERSION"
  local tmp ver name url
  tmp="$(mktemp -d)"
  ver="${EGET_VERSION#v}"
  name="eget-$ver-$(eget_platform)"
  url="https://github.com/zyedidia/eget/releases/download/$EGET_VERSION/$name.tar.gz"
  if have curl; then
    curl -fsSL "$url" -o "$tmp/eget.tar.gz"
  elif have wget; then
    wget -qO "$tmp/eget.tar.gz" "$url"
  else
    die "Need curl or wget to download eget"
  fi
  tar -xzf "$tmp/eget.tar.gz" -C "$tmp" "$name/eget"
  mv "$tmp/$name/eget" "$BIN/eget"
  rm -rf "$tmp"
  stamp eget "$EGET_VERSION"
}

# eget_tool <binary-name> <version> <owner/repo> [extra eget args...]
eget_tool() {
  local name="$1" version="$2"; shift 2
  needs_install "$name" "$BIN/$name" "$version" || return 0
  log "Installing $name $version"
  "$BIN/eget" "$@" --tag "$version" --to "$BIN/$name"
  stamp "$name" "$version"
}

# Neovim needs its runtime files next to the binary, so unpack the whole
# release tarball into ~/.local/opt/nvim and symlink the binary.
install_nvim() {
  needs_install nvim "$OPT/nvim/bin/nvim" "$NVIM_VERSION" || return 0
  log "Installing nvim $NVIM_VERSION"
  local tmp archive
  tmp="$(mktemp -d)"
  (cd "$tmp" && "$BIN/eget" neovim/neovim --tag "$NVIM_VERSION" \
    --asset .tar.gz --asset ^sha --download-only)
  archive="$(find "$tmp" -name '*.tar.gz' | head -n 1)"
  [ -n "$archive" ] || die "Could not download Neovim"
  rm -rf "$OPT/nvim"
  mkdir -p "$OPT/nvim"
  tar -xzf "$archive" -C "$OPT/nvim" --strip-components=1
  ln -sfn "$OPT/nvim/bin/nvim" "$BIN/nvim"
  rm -rf "$tmp"
  stamp nvim "$NVIM_VERSION"
}

# tmux has no official prebuilt binaries, so use the system package manager.
install_tmux() {
  if have tmux; then
    return
  fi
  if [ "$OS" = Darwin ]; then
    warn "tmux not found; install it with: brew install tmux"
    return
  fi
  local sudo=""
  if [ "$(id -u)" != 0 ]; then
    if have sudo; then
      sudo="sudo"
    else
      warn "tmux not found and no sudo available; install tmux manually"
      return
    fi
  fi
  log "Installing tmux via system package manager"
  if have apt-get; then
    $sudo apt-get update -qq && $sudo apt-get install -y tmux
  elif have dnf; then
    $sudo dnf install -y tmux
  elif have yum; then
    $sudo yum install -y tmux
  elif have pacman; then
    $sudo pacman -S --noconfirm --needed tmux
  elif have zypper; then
    $sudo zypper --non-interactive install tmux
  elif have apk; then
    $sudo apk add tmux
  else
    warn "No supported package manager found; install tmux manually"
  fi
}

# TPM manages the tmux plugins listed in tmux.conf. Runs after the configs are
# linked, since install_plugins reads ~/.tmux.conf.
TPM="$HOME/.tmux/plugins/tpm"

install_tmux_plugins() {
  if ! have tmux || ! have git; then
    warn "tmux or git not found; skipping tmux plugins"
    return
  fi
  if [ ! -d "$TPM" ]; then
    log "Installing tpm $TPM_VERSION"
    git -c advice.detachedHead=false clone -q --depth 1 --branch "$TPM_VERSION" https://github.com/tmux-plugins/tpm "$TPM"
  elif [ "$(git -C "$TPM" describe --tags --exact-match 2>/dev/null)" != "$TPM_VERSION" ]; then
    log "Switching tpm to $TPM_VERSION"
    git -C "$TPM" fetch -q --depth 1 origin tag "$TPM_VERSION"
    git -C "$TPM" -c advice.detachedHead=false checkout -q "$TPM_VERSION"
  fi
  # TPM clones each plugin at the ref after '#' in its @plugin line but never
  # moves an existing clone, so wipe the plugins when those lines change.
  local plugins
  plugins="$(grep -E "^set -g @plugin" "$DOTFILES/tmux/tmux.conf")"
  if [ "$UPDATE" = 1 ] || [ "$(cat "$STAMPS/tmux-plugins" 2>/dev/null)" != "$plugins" ]; then
    find "$HOME/.tmux/plugins" -mindepth 1 -maxdepth 1 ! -name tpm -exec rm -rf {} +
  fi
  # TPM's scripts talk to a tmux server that has loaded tmux.conf. Start a
  # throwaway one on its own socket so running sessions are left alone.
  log "Installing tmux plugins"
  local sock
  sock="$(mktemp -d)"
  (
    unset TMUX
    export TMUX_TMPDIR="$sock"
    tmux -f "$HOME/.tmux.conf" new-session -d
    "$TPM/bin/install_plugins" >/dev/null
    tmux kill-server
  ) && stamp tmux-plugins "$plugins" ||
    warn "tmux plugin install failed; run prefix I inside tmux"
  rm -rf "$sock"
}

# eza publishes no macOS builds.
install_eza() {
  if [ "$OS" = Darwin ]; then
    have eza || warn "eza not found; install it with: brew install eza"
    return
  fi
  eget_tool eza "$EZA_VERSION" eza-community/eza --asset .tar.gz --asset ^no_libgit "$@"
}

install_tools() {
  mkdir -p "$BIN" "$OPT"
  export PATH="$BIN:$PATH"

  # On Linux prefer statically linked musl builds: they run on old glibc too.
  local libc=()
  if [ "$OS" = Linux ]; then
    libc=(--asset musl)
  fi
  # Some projects only publish musl builds for x86_64.
  local musl_x86=()
  if [ "$OS" = Linux ] && [ "$(uname -m)" = x86_64 ]; then
    musl_x86=(--asset musl)
  fi

  install_eget
  install_nvim
  eget_tool fzf      "$FZF_VERSION"      junegunn/fzf
  eget_tool zoxide   "$ZOXIDE_VERSION"   ajeetdsouza/zoxide --asset .tar.gz
  eget_tool fd       "$FD_VERSION"       sharkdp/fd         --asset .tar.gz "${libc[@]+"${libc[@]}"}"
  eget_tool bat      "$BAT_VERSION"      sharkdp/bat        --asset .tar.gz "${libc[@]+"${libc[@]}"}"
  eget_tool rg       "$RG_VERSION"       BurntSushi/ripgrep --asset .tar.gz --asset ^sha "${libc[@]+"${libc[@]}"}"
  eget_tool lazygit  "$LAZYGIT_VERSION"  jesseduffield/lazygit --asset .tar.gz
  eget_tool yazi     "$YAZI_VERSION"     sxyazi/yazi        --asset .zip "${libc[@]+"${libc[@]}"}" --file yazi
  eget_tool ya       "$YAZI_VERSION"     sxyazi/yazi        --asset .zip "${libc[@]+"${libc[@]}"}" --file ya
  eget_tool delta    "$DELTA_VERSION"    dandavison/delta   --asset .tar.gz "${musl_x86[@]+"${musl_x86[@]}"}"
  eget_tool starship "$STARSHIP_VERSION" starship/starship  --asset .tar.gz "${libc[@]+"${libc[@]}"}"
  eget_tool jq       "$JQ_VERSION"       jqlang/jq          --asset ^osx --asset ^linux64 --asset ^attestation
  eget_tool yq       "$YQ_VERSION"       mikefarah/yq       --asset ^.tar.gz --asset ^checksums --asset ^bundle
  install_eza "${musl_x86[@]+"${musl_x86[@]}"}"
  install_tmux
}

# ---------------------------------------------------------------------------
# Config symlinks
# ---------------------------------------------------------------------------

# link <path-in-repo> <destination>; existing files are moved to $BACKUP.
link() {
  local src="$DOTFILES/$1" dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    local bak="$BACKUP/${dst#"$HOME"/}"
    mkdir -p "$(dirname "$bak")"
    mv "$dst" "$bak"
    warn "Backed up $dst -> $bak"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  log "Linked $dst"
}

link_configs() {
  link nvim            "$CONFIG/nvim"
  link tmux/tmux.conf  "$HOME/.tmux.conf"
  link yazi            "$CONFIG/yazi"
  link bat/config      "$CONFIG/bat/config"
  link git/config      "$HOME/.gitconfig"
  link starship/starship.toml "$CONFIG/starship.toml"
  link readline/inputrc "$HOME/.inputrc"
  link lazygit/config.yml "$(lazygit_config_dir)/config.yml"
  link ghostty/config  "$CONFIG/ghostty/config"
  link claude/statusline.sh "$HOME/.claude/statusline.sh"
  link git/wt-pick      "$BIN/wt-pick"
  link tmux/pane-dir    "$BIN/pane-dir"
  link tmux/scratch     "$BIN/tmux-scratch"
  link tmux/session     "$BIN/tmux-session"
}

# Claude Code writes its own settings.json, so point statusLine at the linked
# script instead of linking the whole file. Leaves an existing statusLine alone.
set_claude_statusline() {
  local settings="$HOME/.claude/settings.json"
  if ! have jq; then
    warn "jq not found; set statusLine in $settings yourself"
    return
  fi
  [ -f "$settings" ] || echo '{}' > "$settings"
  if jq -e 'has("statusLine")' "$settings" >/dev/null; then
    return
  fi
  local tmp
  tmp="$(mktemp)"
  jq '.statusLine = {type: "command", command: "~/.claude/statusline.sh"}' "$settings" > "$tmp"
  mv "$tmp" "$settings"
  log "Set Claude Code statusLine in $settings"
}

# lazygit uses ~/Library/Application Support on macOS unless XDG_CONFIG_HOME
# is set.
lazygit_config_dir() {
  if [ "$OS" = Darwin ] && [ -z "${XDG_CONFIG_HOME:-}" ]; then
    echo "$HOME/Library/Application Support/lazygit"
  else
    echo "$CONFIG/lazygit"
  fi
}

# ---------------------------------------------------------------------------
# Git identity
# ---------------------------------------------------------------------------

GIT_LOCAL="$HOME/.gitconfig.local"

# Ask for the e-mail up front so the rest of the install runs unattended.
# The default is whatever this machine already uses, else DEFAULT_GIT_EMAIL.
ask_git_email() {
  [ -n "$GIT_EMAIL" ] && return
  local current default
  current="$(git config --file "$GIT_LOCAL" user.email 2>/dev/null || true)"
  default="${current:-$DEFAULT_GIT_EMAIL}"
  if [ -t 0 ]; then
    read -r -p "Git e-mail [$default]: " GIT_EMAIL
  fi
  GIT_EMAIL="${GIT_EMAIL:-$default}"
}

set_git_email() {
  if ! have git; then
    warn "git not found; set user.email in $GIT_LOCAL yourself"
    return
  fi
  if [ "$(git config --file "$GIT_LOCAL" user.email 2>/dev/null)" = "$GIT_EMAIL" ]; then
    return
  fi
  git config --file "$GIT_LOCAL" user.email "$GIT_EMAIL"
  log "Set git user.email to $GIT_EMAIL in $GIT_LOCAL"
}

# ---------------------------------------------------------------------------
# Shell hooks
# ---------------------------------------------------------------------------

# hook_rc <rc-file>: append a line sourcing shell/init.sh, once.
hook_rc() {
  local rc="$1"
  local init="$DOTFILES/shell/init.sh"
  if [ -f "$rc" ] && grep -qF "$init" "$rc"; then
    return
  fi
  printf '\n# dotfiles\n[ -f "%s" ] && . "%s"\n' "$init" "$init" >> "$rc"
  log "Hooked $rc"
}

hook_shells() {
  hook_rc "$HOME/.bashrc"
  # Login shells (e.g. ssh, macOS Terminal) read ~/.bash_profile instead of
  # ~/.bashrc; make sure it chains to ~/.bashrc.
  if [ -f "$HOME/.bash_profile" ] && ! grep -q bashrc "$HOME/.bash_profile"; then
    printf '\n# dotfiles\n[ -f ~/.bashrc ] && . ~/.bashrc\n' >> "$HOME/.bash_profile"
    log "Hooked ~/.bash_profile -> ~/.bashrc"
  fi
  if have zsh || [ -f "$HOME/.zshrc" ]; then
    hook_rc "$HOME/.zshrc"
  fi
}

[ "$DO_LINKS" = 1 ] && ask_git_email
[ "$DO_TOOLS" = 1 ] && install_tools
[ "$DO_LINKS" = 1 ] && link_configs && set_git_email && set_claude_statusline
[ "$DO_TOOLS" = 1 ] && [ "$DO_LINKS" = 1 ] && install_tmux_plugins
[ "$DO_SHELL" = 1 ] && hook_shells

log "Done. Restart your shell or run: exec \$SHELL"
