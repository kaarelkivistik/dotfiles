# Shared shell setup, sourced from ~/.bashrc and ~/.zshrc by install.sh.
# Must stay compatible with both bash and zsh.

if [ -n "${ZSH_VERSION:-}" ]; then
  _df_shell=zsh
elif [ -n "${BASH_VERSION:-}" ]; then
  _df_shell=bash
else
  return 0
fi

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

_df_have() { command -v "$1" >/dev/null 2>&1; }

# zsh: completion system must be initialised before fzf/zoxide hook into it.
if [ "$_df_shell" = zsh ] && ! (( $+functions[compdef] )); then
  autoload -Uz compinit && compinit
fi

# --- history ----------------------------------------------------------------
HISTSIZE=100000
if [ "$_df_shell" = zsh ]; then
  SAVEHIST=100000
  HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
  setopt SHARE_HISTORY EXTENDED_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
  # Up/Down search history for lines starting with what you've typed
  # (bash gets the same from ~/.inputrc).
  autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
  zle -N up-line-or-beginning-search
  zle -N down-line-or-beginning-search
  bindkey '^[[A' up-line-or-beginning-search
  bindkey '^[[B' down-line-or-beginning-search
  zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
else
  HISTFILESIZE=100000
  HISTCONTROL=ignoreboth:erasedups
  shopt -s histappend
  # Write each command to the history file as soon as it runs.
  case "${PROMPT_COMMAND:-}" in
    *"history -a"*) ;;
    *) PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
  esac
fi

# --- neovim -----------------------------------------------------------------
if _df_have nvim; then
  export EDITOR=nvim VISUAL=nvim
  alias vim=nvim
  alias vi=nvim
fi

# --- bat --------------------------------------------------------------------
if _df_have bat; then
  _df_have col && export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
  # Read the macOS appearance directly; terminal detection fails when piped.
  [ "$(uname -s)" = Darwin ] && export BAT_THEME=auto:system
fi

# --- appearance -------------------------------------------------------------
# Ghostty, tmux, nvim and bat follow the macOS appearance. `theme` toggles it,
# `theme light` / `theme dark` set it.
if [ "$(uname -s)" = Darwin ]; then
  theme() {
    local mode
    case "${1:-toggle}" in
      light) mode=false ;;
      dark) mode=true ;;
      toggle) mode="not dark mode" ;;
      *) echo "usage: theme [light|dark]" >&2; return 1 ;;
    esac
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $mode"
  }
fi

# --- fzf --------------------------------------------------------------------
if _df_have fzf; then
  export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
  if _df_have fd; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"
  fi
  if _df_have bat; then
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
  fi
  if _df_have eza; then
    export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons=never {} | head -200'"
  fi
  # Ctrl-T: files, Ctrl-R: history, Alt-C: cd into directory
  eval "$(fzf --$_df_shell)"
fi

# --- starship ---------------------------------------------------------------
# Config: ~/.config/starship.toml. Replaces any oh-my-zsh theme.
if _df_have starship; then
  eval "$(starship init $_df_shell)"
fi

# --- zoxide -----------------------------------------------------------------
# z <query> jumps to a frecent directory, zi picks one interactively with fzf.
if _df_have zoxide; then
  eval "$(zoxide init $_df_shell)"
fi

# --- yazi -------------------------------------------------------------------
# `y` opens yazi and cd's into the directory you were in when you quit.
if _df_have yazi; then
  y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
  }
fi

# --- eza --------------------------------------------------------------------
if _df_have eza; then
  alias ll='eza -lah --git --group-directories-first'
  alias lt='eza --tree --level=2 --git-ignore'
else
  alias ll='ls -lah'
fi

_df_have lazygit && alias lg=lazygit

# Machine-specific overrides that shouldn't live in the repo.
[ -f "$HOME/.shell.local" ] && . "$HOME/.shell.local"

unset _df_shell
unset -f _df_have
