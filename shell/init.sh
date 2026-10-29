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
  # Ctrl-T: files, Ctrl-R: history, Alt-C: cd into directory
  eval "$(fzf --$_df_shell)"
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

alias ll='ls -lah'
_df_have lazygit && alias lg=lazygit

# Machine-specific overrides that shouldn't live in the repo.
[ -f "$HOME/.shell.local" ] && . "$HOME/.shell.local"

unset _df_shell
unset -f _df_have
