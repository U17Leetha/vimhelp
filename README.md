# vimhelp

A tiny POSIX shell command that opens [Vim's built-in help](https://vimhelp.org/)
on a topic straight from your terminal — no need to start Vim and fiddle with
`:help` first.

```console
$ vimhelp tabs        # opens :help tabs in Vim
$ vimhelp quickref    # opens Vim's quick reference
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

Both methods install the `vimhelp` command to `~/.local/bin/vimhelp`. The
installer:

- runs with any POSIX `/bin/sh` (no Bash required) on macOS and Linux,
- creates `~/.local/bin` if it does not exist,
- never needs `sudo` and never touches global or shell configuration files,
- refuses to overwrite a non-vimhelp file at the destination,
- uses a temporary file so a failed download can never leave a partial install,
- is safe to re-run: rerunning it updates an existing installation in place.

If `~/.local/bin` is not on your `PATH`, the installer prints the exact line to
add to `~/.bashrc` or `~/.zshrc` itself — it will never modify those files for
you.

## Requirements

- A POSIX shell (`/bin/sh`) — Bash is not required.
- Vim (or Neovim) on your `PATH` to view help topics.

## Usage

```console
$ vimhelp --help        # usage
$ vimhelp --version     # version
$ vimhelp tabs          # open :help tabs
$ vimhelp undo.txt      # open a specific help file
$ vimhelp               # open the help index
```

## Updating

Re-run the installer — it updates `~/.local/bin/vimhelp` in place:

```sh
curl -fsSL https://raw.githubusercontent.com/U17Leetha/vimhelp/main/install.sh | sh
```

## Uninstalling

The installer only writes a single file, so removing it is enough:

```sh
rm ~/.local/bin/vimhelp
```

If you added `~/.local/bin` to your `PATH` for this tool, you can revert that
edit in your shell configuration too.

## Troubleshooting

- **`vimhelp: command not found`** — `~/.local/bin` is not in your `PATH`.
  The installer prints the `export PATH="$HOME/.local/bin:$PATH"` line to add
  to `~/.bashrc` (Bash) or `~/.zshrc` (Zsh); restart your shell afterwards.
- **`vimhelp: neither vim nor nvim was found in PATH`** — install Vim
  (e.g. `brew install vim` on macOS, your distro package manager on Linux).
- **`... already exists and is not a vimhelp installation`** — some other
  program occupies `~/.local/bin/vimhelp`. Remove or move it, then re-run the
  installer.
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
