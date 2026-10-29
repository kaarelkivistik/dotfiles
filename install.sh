#!/usr/bin/env bash
# Bootstrap: install CLI tools into ~/.local (no root needed), link configs,
# and hook shell/init.sh into bash and zsh. Safe to re-run.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
OPT="$HOME/.local/opt"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

UPDATE=0
DO_TOOLS=1
DO_LINKS=1
DO_SHELL=1

usage() {
  cat <<EOF
Usage: $0 [options]

  -u, --update     Reinstall tools even if already present (pulls latest releases)
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
    --no-tools) DO_TOOLS=0 ;;
    --no-links) DO_LINKS=0 ;;
    --no-shell) DO_SHELL=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"
case "$OS" in
  Linux|Darwin) ;;
  *) die "Unsupported OS: $OS" ;;
esac

# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------

install_eget() {
  if [ -x "$BIN/eget" ] && [ "$UPDATE" = 0 ]; then
    return
  fi
  log "Installing eget"
  local tmp
  tmp="$(mktemp -d)"
  if have curl; then
    curl -fsSL https://zyedidia.github.io/eget.sh -o "$tmp/eget.sh"
  elif have wget; then
    wget -qO "$tmp/eget.sh" https://zyedidia.github.io/eget.sh
  else
    die "Need curl or wget to download eget"
  fi
  (cd "$tmp" && bash eget.sh >/dev/null)
  mv "$tmp/eget" "$BIN/eget"
  rm -rf "$tmp"
}

# eget_tool <binary-name> <owner/repo> [extra eget args...]
eget_tool() {
  local name="$1"; shift
  if [ -x "$BIN/$name" ] && [ "$UPDATE" = 0 ]; then
    return
  fi
  log "Installing $name"
  "$BIN/eget" "$@" --to "$BIN"
}

# Neovim needs its runtime files next to the binary, so unpack the whole
# release tarball into ~/.local/opt/nvim and symlink the binary.
install_nvim() {
  if [ -x "$OPT/nvim/bin/nvim" ] && [ "$UPDATE" = 0 ]; then
    return
  fi
  log "Installing nvim"
  local tmp archive
  tmp="$(mktemp -d)"
  (cd "$tmp" && "$BIN/eget" neovim/neovim --asset .tar.gz --asset ^sha --download-only)
  archive="$(find "$tmp" -name '*.tar.gz' | head -n 1)"
  [ -n "$archive" ] || die "Could not download Neovim"
  rm -rf "$OPT/nvim"
  mkdir -p "$OPT/nvim"
  tar -xzf "$archive" -C "$OPT/nvim" --strip-components=1
  ln -sfn "$OPT/nvim/bin/nvim" "$BIN/nvim"
  rm -rf "$tmp"
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

install_tools() {
  mkdir -p "$BIN" "$OPT"
  export PATH="$BIN:$PATH"

  # On Linux prefer statically linked musl builds: they run on old glibc too.
  local libc=()
  if [ "$OS" = Linux ]; then
    libc=(--asset musl)
  fi

  install_eget
  install_nvim
  eget_tool fzf     junegunn/fzf
  eget_tool zoxide  ajeetdsouza/zoxide --asset .tar.gz
  eget_tool fd      sharkdp/fd         --asset .tar.gz "${libc[@]+"${libc[@]}"}"
  eget_tool bat     sharkdp/bat        --asset .tar.gz "${libc[@]+"${libc[@]}"}"
  eget_tool rg      BurntSushi/ripgrep --asset .tar.gz --asset ^sha "${libc[@]+"${libc[@]}"}"
  eget_tool lazygit jesseduffield/lazygit --asset .tar.gz
  eget_tool yazi    sxyazi/yazi        --asset .zip "${libc[@]+"${libc[@]}"}" --file yazi
  eget_tool ya      sxyazi/yazi        --asset .zip "${libc[@]+"${libc[@]}"}" --file ya
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

[ "$DO_TOOLS" = 1 ] && install_tools
[ "$DO_LINKS" = 1 ] && link_configs
[ "$DO_SHELL" = 1 ] && hook_shells

log "Done. Restart your shell or run: exec \$SHELL"
