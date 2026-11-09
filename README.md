---
charter: readme
---

# vimhelp

Two tiny POSIX shell commands for everyday Vim reference:

- **`vimhelp`** — prints a plain cheat sheet of commonly used Vim commands and
  exits. No navigation, no pager, no editor.
- **`vimtopic`** — opens [Vim's built-in help](https://vimhelp.org/) on a topic
  straight from your terminal, for when the cheat sheet is not enough.

```console
$ vimhelp             # instant cheat sheet
$ vimtopic tabs       # opens :help tabs in Vim
$ vimtopic quickref   # opens Vim's quick reference
```

## Installation

### Method 1 — One-line installer (recommended)

```sh
curl -fsSL https://raw.githubusercontent.com/U17Leetha/vimhelp/main/install.sh | sh
```

> **Review first.** Piping remote shell code to `sh` is convenient but you
> should always inspect the script before running it:
>
> ```sh
> curl -fsSL https://raw.githubusercontent.com/U17Leetha/vimhelp/main/install.sh | less
> ```

### Method 2 — Clone and install

```sh
git clone https://github.com/U17Leetha/vimhelp.git
cd vimhelp
sh install.sh
```

Both methods install `vimhelp` and `vimtopic` to `~/.local/bin/`. The
installer:

- runs with any POSIX `/bin/sh` (no Bash required) on macOS and Linux,
- creates `~/.local/bin` if it does not exist,
- never needs `sudo` and never touches global or shell configuration files,
- refuses to overwrite files at the destinations that are not part of this
  project,
- fetches and validates every command before installing any, so a failed
  download can never leave a partial install,
- is safe to re-run: rerunning it updates an existing installation in place.

If `~/.local/bin` is not on your `PATH`, the installer prints the exact line to
add to `~/.bashrc` or `~/.zshrc` itself — it will never modify those files for
you.

## Requirements

- A POSIX shell (`/bin/sh`) — Bash is not required.
- Vim (or Neovim) on your `PATH`, only needed for `vimtopic`.

## Usage

### vimhelp — the cheat sheet

```console
$ vimhelp             # print the cheat sheet and exit
```

### vimtopic — the help browser

```console
$ vimtopic --help     # usage
$ vimtopic --version  # version
$ vimtopic tabs       # open :help tabs
$ vimtopic undo.txt   # open a specific help file
$ vimtopic            # open the help index
```

Inside the help window: `Ctrl-]` follows the tag under the cursor, `Ctrl-t`
jumps back, `:q` closes the window.

## Updating

Re-run the installer — it updates both commands in place:

```sh
curl -fsSL https://raw.githubusercontent.com/U17Leetha/vimhelp/main/install.sh | sh
```

## Uninstalling

The installer only writes two files, so removing them is enough:

```sh
rm ~/.local/bin/vimhelp ~/.local/bin/vimtopic
```

If you added `~/.local/bin` to your `PATH` for these tools, you can revert that
edit in your shell configuration too.

## Troubleshooting

- **`vimhelp: command not found`** — `~/.local/bin` is not in your `PATH`.
  The installer prints the `export PATH="$HOME/.local/bin:$PATH"` line to add
  to `~/.bashrc` (Bash) or `~/.zshrc` (Zsh); restart your shell afterwards.
- **`vimtopic: neither vim nor nvim was found in PATH`** — install Vim
  (e.g. `brew install vim` on macOS, your distro package manager on Linux).
- **`... already exists and is not a vimhelp/vimtopic installation`** — some
  other program occupies that name in `~/.local/bin`. Remove or move it, then
  re-run the installer.
- **Download fails during the one-line install** — check network/HTTPS access
  to `raw.githubusercontent.com`, or use the clone method instead.

## Tests

From a clone of this repository:

```sh
sh tests/test.sh
```

The suite runs the installer into throwaway `HOME` directories only; it never
modifies your real shell configuration.

## License

MIT — see [LICENSE](LICENSE).
