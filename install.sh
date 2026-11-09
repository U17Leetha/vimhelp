#!/bin/sh
# install.sh - install or update the vimhelp and vimtopic commands.
#
# Supports both installation methods:
#   1. Piped:  curl -fsSL https://raw.githubusercontent.com/U17Leetha/vimhelp/main/install.sh | sh
#   2. Clone:  git clone https://github.com/U17Leetha/vimhelp.git && cd vimhelp && sh install.sh
#
# Behaviour:
#   * POSIX /bin/sh compatible (no Bash required); works on macOS and Linux.
#   * Installs to $HOME/.local/bin/, creating the directory if needed.
#   * Never requires sudo/root and never modifies shell or global config files.
#   * Re-running the installer updates an existing installation in place.
#   * Refuses to overwrite a destination that is not part of this project.
#   * Piped runs download the commands from the pinned official repository
#     over HTTPS; cloned runs install the local copies beside this script.
#   * All commands are fetched and validated before any is installed, so a
#     failure never leaves the toolkit partially changed.
#
# Commands:
#   vimhelp    Plain printable cheat sheet of common Vim commands.
#   vimtopic   Opens Vim's built-in :help browser on a topic.
#
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 U17Leetha

set -eu

REPO_URL="https://github.com/U17Leetha/vimhelp"
# Downloads are pinned to the official repository over HTTPS. VIMHELP_RAW_BASE
# overrides the source (used by the test suite to simulate an unreachable
# source without touching the network).
RAW_BASE="${VIMHELP_RAW_BASE:-https://raw.githubusercontent.com/U17Leetha/vimhelp/main}"
# The commands shipped by this project, in install order.
PROGS="vimhelp vimtopic"

if [ -z "${HOME:-}" ]; then
    printf 'vimhelp-install: HOME is not set; cannot determine install location.\n' >&2
    exit 1
fi

DEST_DIR="${HOME}/.local/bin"

say() {
    printf '%s\n' "$*"
}

die() {
    printf 'vimhelp-install: %s\n' "$*" >&2
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1
}

# Unique marker embedded in each shipped script; used to recognise our own
# installations and to sanity-check downloaded content.
marker_for() {
    case "$1" in
        vimhelp)  printf 'vimhelp-install-marker: U17Leetha/vimhelp\n' ;;
        vimtopic) printf 'vimtopic-install-marker: U17Leetha/vimhelp\n' ;;
        *)        die "internal error: no marker defined for $1" ;;
    esac
}

# --- staging + cleanup -------------------------------------------------------
# Everything is gathered into a temporary directory and only moved into place
# after every command has been fully fetched and validated. Any exit path
# cleans up the staging area; the destination is never partially updated.
WORKDIR=""
STAGED=""
cleanup() {
    [ -n "$WORKDIR" ] && rm -rf "$WORKDIR" 2>/dev/null || true
    [ -n "$STAGED" ] && rm -f "$STAGED" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

if need mktemp; then
    WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/vimhelp-install.XXXXXXXXXX")" \
        || die "could not create temporary directory"
else
    WORKDIR="${TMPDIR:-/tmp}/vimhelp-install.$$"
    mkdir -p "$WORKDIR" || die "could not create temporary directory"
fi

# --- resolve the source for each command --------------------------------------
# Prefer the copies that ship beside this installer (clone method). When the
# installer itself is streamed through stdin, $0 does not point at the
# repository, so download from the pinned official source instead.
SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)" || SELF_DIR=""

for name in $PROGS; do
    SRC="$WORKDIR/$name"
    if [ -n "$SELF_DIR" ] && [ -f "${SELF_DIR}/${name}" ]; then
        say "Using ${name} script from local repository: ${SELF_DIR}/${name}"
        cat -- "${SELF_DIR}/${name}" > "$SRC" \
            || die "could not read ${SELF_DIR}/${name}"
    else
        say "Streaming install detected; downloading ${name} from ${REPO_URL} ..."
        if need curl; then
            curl -fsSL "${RAW_BASE}/${name}" -o "$SRC" \
                || die "download failed: ${RAW_BASE}/${name} (network error or not found)"
        elif need wget; then
            wget -q -O "$SRC" "${RAW_BASE}/${name}" \
                || die "download failed: ${RAW_BASE}/${name} (network error or not found)"
        else
            die "piped installation requires curl or wget to download ${name}; or use the git clone method"
        fi
    fi
done

# --- validate every source before installing any -------------------------------
for name in $PROGS; do
    SRC="$WORKDIR/$name"
    [ -s "$SRC" ] || die "the ${name} script is missing or empty; aborting without changes"
    grep -q "$(marker_for "$name")" "$SRC" \
        || die "source does not look like a ${name} script (marker not found); aborting without changes"
done

# --- refuse to clobber unrelated files -----------------------------------------
for name in $PROGS; do
    DEST_FILE="${DEST_DIR}/${name}"
    if [ -e "$DEST_FILE" ] || [ -L "$DEST_FILE" ]; then
        if grep -q "$(marker_for "$name")" "$DEST_FILE" 2>/dev/null; then
            say "Existing ${name} installation found; updating in place."
        else
            die "${DEST_FILE} already exists and is not a ${name} installation. Refusing to overwrite it. Remove or move that file first, then re-run the installer."
        fi
    fi
done

# --- install --------------------------------------------------------------------
mkdir -p "$DEST_DIR" || die "could not create ${DEST_DIR}"

for name in $PROGS; do
    DEST_FILE="${DEST_DIR}/${name}"
    # Stage inside the destination directory so the final move is atomic on
    # the same filesystem, and so a failure can never leave a partial command.
    STAGED="${DEST_FILE}.install.$$"
    cat -- "$WORKDIR/$name" > "$STAGED" || die "could not write ${STAGED}"
    chmod 755 "$STAGED" || die "could not make ${STAGED} executable"
    mv -f -- "$STAGED" "$DEST_FILE" || die "could not move staged file into place"
    STAGED=""
    [ -x "$DEST_FILE" ] || die "installation failed: ${DEST_FILE} is not executable"
    say "Installed ${name} to ${DEST_FILE}"
done

# --- PATH guidance (never modifies shell configuration) --------------------------
case ":${PATH:-}:" in
    *":${DEST_DIR}:"*)
        say "You can now run: vimhelp   and:   vimtopic --help"
        ;;
    *)
        say ""
        say "WARNING: ${DEST_DIR} is not in your PATH, so the commands will not be found yet."
        say "Add it to your shell configuration yourself, e.g.:"
        case "${SHELL:-}" in
            */zsh)
                say "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
                say "Then restart your shell or run:  export PATH=\"\$HOME/.local/bin:\$PATH\""
                ;;
            *)
                say "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
                say "Then restart your shell or run:  export PATH=\"\$HOME/.local/bin:\$PATH\""
                ;;
        esac
        ;;
esac

exit 0
