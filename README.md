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

At the start it asks for the git e-mail to use on this machine. The default is
the e-mail already set there, or `kaarelkivistik@gmail.com` on a fresh machine.
Press Enter to keep it. When stdin isn't a terminal (e.g. `curl | bash`) it uses
the default without asking.

| Option        | Effect                                                  |
| ------------- | ------------------------------------------------------- |
| `-u, --update`| Reinstall every tool from its latest GitHub release     |
| `--git-email ADDR` | Set the git e-mail without prompting               |
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
| delta   | Pager for `git diff`/`log`/`show`, `git add -p` and lazygit (side by side when the panel is wide; `\|` cycles to git's plain diff) |
| starship| Prompt for bash and zsh. Shows the hostname only over SSH          |
| eza     | `ll` and `lt` (tree), plus the `Alt-C` preview. No macOS builds, so on macOS it prints a `brew install eza` hint |
| jq, yq  | JSON and YAML/TOML/XML on the command line                         |
| tmux    | No official binaries. Installed with apt/dnf/yum/pacman/zypper/apk via `sudo` on Linux. On macOS it prints a `brew install tmux` hint. Plugins (tmux-resurrect) are managed by TPM in `~/.tmux/plugins` |

On Linux it picks the static musl builds, so they also run on older distros.

**Configs.** It symlinks these from the repo, so `git pull` updates them. Any
existing file is moved to `~/.dotfiles-backup/<timestamp>/` first.

| Repo             | Linked to               |
| ---------------- | ----------------------- |
| `nvim/`          | `~/.config/nvim`        |
| `tmux/tmux.conf` | `~/.tmux.conf`          |
| `yazi/`          | `~/.config/yazi`        |
| `bat/config`     | `~/.config/bat/config`  |
| `git/config`     | `~/.gitconfig`          |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `readline/inputrc` | `~/.inputrc`          |
| `lazygit/config.yml` | `~/.config/lazygit/config.yml` (`~/Library/Application Support/lazygit/` on macOS) |
| `ghostty/config` | `~/.config/ghostty/config` |

**Shell.** It appends one line to `~/.bashrc` and `~/.zshrc` that sources
`shell/init.sh`. That file works in both shells: it puts `~/.local/bin` on
`PATH` and sets up history, the prompt, fzf, zoxide, yazi and the aliases. Put machine-specific
settings in `~/.shell.local`. It is sourced last and is not part of the repo.

History keeps 100k entries and is written right away, so every shell and
tmux pane shares it. Up/Down search for commands that start with what you've
typed, and tab completion ignores case.

**Git.** `git/config` holds shared settings: delta as pager, rebase on pull,
`push.autoSetupRemote`, `rerere`, histogram diffs. It includes
`~/.gitconfig.local` last. That file holds the e-mail and anything else
specific to the machine, and it overrides the shared settings.

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
| `prefix Ctrl-s`     | Save sessions (tmux-resurrect)  |
| `prefix Ctrl-r`     | Restore saved sessions          |
| `prefix I` / `U`    | Install / update plugins (TPM)  |

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

**Git aliases.**

| Alias          | Runs                                   |
| -------------- | -------------------------------------- |
| `git st`       | `status -sb`                           |
| `git lg`       | One-line graph log                     |
| `git last`     | Last commit with changed files         |
| `git amend`    | `commit --amend --no-edit`             |
| `git unstage`  | `restore --staged`                     |
| `git co/sw/br/ci` | `checkout`/`switch`/`branch`/`commit` |

In delta, `n`/`N` jump between files.

## Uninstall

```sh
rm -rf ~/.local/opt/nvim ~/.config/nvim ~/.config/yazi ~/.config/bat/config ~/.tmux.conf ~/.tmux/plugins
rm -f ~/.gitconfig ~/.gitconfig.local ~/.config/starship.toml ~/.inputrc
rm -f ~/.config/lazygit/config.yml ~/Library/Application\ Support/lazygit/config.yml
rm -f ~/.local/bin/{eget,nvim,fzf,zoxide,fd,bat,rg,lazygit,yazi,ya,delta,starship,eza,jq,yq}
# restore anything you want back from ~/.dotfiles-backup/
# then remove the "# dotfiles" lines from ~/.bashrc and ~/.zshrc
```
