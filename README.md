# dotfiles

My portable shell environment for new servers, VMs and laptops. Everything
installs into `~/.local`, so no root is needed (except for tmux on Linux, see
below).

## Install

```sh
git clone git@github.com:kaarelkivistik/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
exec $SHELL
```

Requirements: `bash`, `curl` or `wget`, `tar`, and `git` (Neovim uses it to fetch plugins).

Re-running `install.sh` is safe. It skips tools that are already installed and
only links or hooks what is missing.

| Option        | Effect                                                  |
| ------------- | ------------------------------------------------------- |
| `-u, --update`| Reinstall every tool from its latest GitHub release     |
| `--no-tools`  | Only link configs and hook the shell                    |
| `--no-links`  | Don't touch config files                                |
| `--no-shell`  | Don't edit `~/.bashrc` / `~/.zshrc`                     |

GitHub allows 60 unauthenticated API requests per hour. If you hit the limit
(for example behind a shared NAT), `export GITHUB_TOKEN=...` first.

## What it does

**Tools.** It installs [eget](https://github.com/zyedidia/eget) to `~/.local/bin`
and uses it to download prebuilt binaries from GitHub releases:

| Tool    | Notes                                                              |
| ------- | ------------------------------------------------------------------ |
| neovim  | Full release unpacked to `~/.local/opt/nvim`, symlinked into `~/.local/bin` |
| fzf     | `Ctrl-T` files, `Ctrl-R` history, `Alt-C` cd                        |
| zoxide  | `z foo` jumps to a frecent dir, `zi` picks one with fzf             |
| fd      | Used as fzf's file source                                          |
| bat     | Used for fzf previews and as `MANPAGER`                            |
| ripgrep | Used by `<space>fg` (live grep) in Neovim                          |
| lazygit | Git TUI; run `lg`                                                  |
| yazi    | Run `y` to browse; quitting cds into the last directory            |
| tmux    | No official binaries. Installed with apt/dnf/yum/pacman/zypper/apk via `sudo` on Linux. On macOS it prints a `brew install tmux` hint |

On Linux it picks the static musl builds, so they also run on older distros.

**Configs.** It symlinks these from the repo, so `git pull` updates them. Any
existing file is moved to `~/.dotfiles-backup/<timestamp>/` first.

| Repo             | Linked to               |
| ---------------- | ----------------------- |
| `nvim/`          | `~/.config/nvim`        |
| `tmux/tmux.conf` | `~/.tmux.conf`          |
| `yazi/`          | `~/.config/yazi`        |
| `bat/config`     | `~/.config/bat/config`  |

**Shell.** It appends one line to `~/.bashrc` and `~/.zshrc` that sources
`shell/init.sh`. That file works in both shells: it puts `~/.local/bin` on
`PATH` and sets up fzf, zoxide, yazi and the aliases. Put machine-specific
settings in `~/.shell.local`. It is sourced last and is not part of the repo.

## Cheatsheet

**tmux.** The prefix is `Ctrl-a`.

| Keys                | Action                          |
| ------------------- | ------------------------------- |
| `prefix \|` / `-`   | Split side by side / stacked    |
| `prefix h j k l`    | Move between panes              |
| `prefix H J K L`    | Resize pane (repeatable)        |
| `prefix Ctrl-h/l`   | Previous / next window          |
| `prefix [`          | Copy mode (`v` select, `y` copy)|
| `prefix r`          | Reload config                   |

The mouse is on: click to focus, drag borders to resize, scroll to see history.

**Neovim.** The leader key is `Space`. Press it and wait to see every mapping.

| Keys                | Action                    |
| ------------------- | ------------------------- |
| `<space>ff`         | Find files                |
| `<space>fg`         | Live grep                 |
| `<space>fb`         | Buffers                   |
| `<space>fr`         | Recent files              |
| `<space><space>`    | Resume last search        |
| `Ctrl-h/j/k/l`      | Move between windows      |

## Uninstall

```sh
rm -rf ~/.local/opt/nvim ~/.config/nvim ~/.config/yazi ~/.config/bat/config ~/.tmux.conf
rm -f ~/.local/bin/{eget,nvim,fzf,zoxide,fd,bat,rg,lazygit,yazi,ya}
# then remove the "# dotfiles" lines from ~/.bashrc and ~/.zshrc
```
