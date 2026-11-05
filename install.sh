#!/bin/sh
# install.sh - install or update the vimhelp command.
#
# Supports both installation methods:
#   1. Piped:  curl -fsSL https://raw.githubusercontent.com/U17Leetha/vimhelp/main/install.sh | sh
#   2. Clone:  git clone https://github.com/U17Leetha/vimhelp.git && cd vimhelp && sh install.sh
#
# Behaviour:
#   * POSIX /bin/sh compatible (no Bash required); works on macOS and Linux.
#   * Installs to $HOME/.local/bin/vimhelp, creating the directory if needed.
#   * Never requires sudo/root and never modifies shell or global config files.
#   * Re-running the installer updates an existing vimhelp installation.
#   * Refuses to overwrite a destination that is not a vimhelp installation.
#   * Piped runs download the command from the pinned official repository over
#     HTTPS; cloned runs install the local copy that ships beside this script.
#   * Failed downloads never leave a partially installed command behind.
#
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 U17Leetha

set -eu

PROG="vimhelp"
REPO_URL="https://github.com/U17Leetha/vimhelp"
# Downloads are pinned to the official repository over HTTPS.
RAW_BASE="https://raw.githubusercontent.com/U17Leetha/vimhelp/main"
# Unique marker embedded in the vimhelp script; used to recognise our own
# installations and to sanity-check downloaded content.
MARKER="vimhelp-install-marker: U17Leetha/vimhelp"

if [ -z "${HOME:-}" ]; then
    printf 'vimhelp-install: HOME is not set; cannot determine install location.\n' >&2
    exit 1
fi

DEST_DIR="${HOME}/.local/bin"
DEST_FILE="${DEST_DIR}/${PROG}"

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

# --- staging + cleanup -------------------------------------------------------
# All downloads happen in a temporary file; it is only moved into place after
# it has been fully downloaded and validated. Any exit path cleans it up.
TMP=""
STAGED=""
cleanup() {
    [ -n "$TMP" ] && rm -f "$TMP" 2>/dev/null || true
    [ -n "$STAGED" ] && rm -f "$STAGED" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

make_tmp() {
    # $1: suffix for the temporary file name.
    if need mktemp; then
        mktemp "${TMPDIR:-/tmp}/vimhelp-install.XXXXXXXXXX"
    else
        printf '%s/%s.install.%s.%s' \
            "${TMPDIR:-/tmp}" "$PROG" "$$" "$1"
    fi
}

# --- resolve the vimhelp script to install -----------------------------------
# Prefer the copy that ships beside this installer (clone method). When the
# installer itself is streamed through stdin, $0 does not point at the
# repository, so download from the pinned official source instead.
SELF_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)" || SELF_DIR=""

if [ -n "$SELF_DIR" ] && [ -f "${SELF_DIR}/${PROG}" ]; then
    SRC="${SELF_DIR}/${PROG}"
    say "Using vimhelp script from local repository: ${SRC}"
else
    say "Streaming install detected; downloading ${PROG} from ${REPO_URL} ..."
    if need curl; then
        TMP="$(make_tmp dl)"
        curl -fsSL "${RAW_BASE}/${PROG}" -o "$TMP" \
            || die "download failed: ${RAW_BASE}/${PROG} (network error or not found)"
    elif need wget; then
        TMP="$(make_tmp dl)"
        wget -q -O "$TMP" "${RAW_BASE}/${PROG}" \
            || die "download failed: ${RAW_BASE}/${PROG} (network error or not found)"
    else
        die "piped installation requires curl or wget to download ${PROG}; or use the git clone method"
    fi
    SRC="$TMP"
fi

# --- validate the source -------------------------------------------------------
[ -s "$SRC" ] || die "the ${PROG} script is missing or empty; aborting without changes"
grep -q "$MARKER" "$SRC" \
    || die "source does not look like a ${PROG} script (marker not found); aborting without changes"

# --- refuse to clobber unrelated files -----------------------------------------
if [ -e "$DEST_FILE" ] || [ -L "$DEST_FILE" ]; then
    if grep -q "$MARKER" "$DEST_FILE" 2>/dev/null; then
        say "Existing ${PROG} installation found; updating in place."
    else
        die "${DEST_FILE} already exists and is not a ${PROG} installation. Refusing to overwrite it. Remove or move that file first, then re-run the installer."
    fi
fi

# --- install --------------------------------------------------------------------
mkdir -p "$DEST_DIR" || die "could not create ${DEST_DIR}"

# Stage inside the destination directory so the final move is atomic on the
# same filesystem, and so a failure can never leave a partial command.
STAGED="${DEST_FILE}.install.$$"
cat -- "$SRC" > "$STAGED" || die "could not write ${STAGED}"
chmod 755 "$STAGED" || die "could not make ${STAGED} executable"
mv -f -- "$STAGED" "$DEST_FILE" || die "could not move staged file into place"
STAGED=""

[ -x "$DEST_FILE" ] || die "installation failed: ${DEST_FILE} is not executable"

say "Installed ${PROG} to ${DEST_FILE}"

# --- PATH guidance (never modifies shell configuration) --------------------------
case ":${PATH:-}:" in
    *":${DEST_DIR}:"*)
        say "You can now run: ${PROG} --help"
        ;;
    *)
        say ""
        say "WARNING: ${DEST_DIR} is not in your PATH, so the '${PROG}' command will not be found yet."
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
