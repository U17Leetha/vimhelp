#!/bin/sh
# tests/test.sh - verification suite for vimhelp and its installer.
#
# Every test runs the installer against a throwaway HOME under a temporary
# directory. Nothing here ever reads or writes your real HOME or shell
# configuration files.
#
# Usage:
#   sh tests/test.sh                 # tests that pass from a clone
#   PUBLISHED=1 sh tests/test.sh     # additionally test the published
#                                    # one-line install against GitHub
#
# SPDX-License-Identifier: MIT

set -u

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/vimhelp-tests.XXXXXXXXXX")" || {
    printf 'cannot create temporary directory\n' >&2
    exit 1
}
cleanup() { rm -rf "$WORK" 2>/dev/null || true; }
trap cleanup EXIT HUP INT TERM

pass=0
fail=0

ok() {
    pass=$((pass + 1))
    printf 'ok - %s\n' "$*"
}
nok() {
    fail=$((fail + 1))
    printf 'not ok - %s\n' "$*"
}
check() {
    # check <expected-status> <actual-status> <description>
    if [ "$1" -eq "$2" ]; then ok "$3"; else nok "$3 (expected exit $1, got $2)"; fi
}
file_x() {
    if [ -f "$1" ] && [ -x "$1" ]; then ok "$2"; else nok "$2"; fi
}
contains() {
    # contains <haystack-file> <needle> <description>
    if grep -q -- "$2" "$1" 2>/dev/null; then ok "$3"; else nok "$3"; fi
}
absent() {
    if ! grep -q -- "$2" "$1" 2>/dev/null; then ok "$3"; else nok "$3"; fi
}

msg_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null || echo unknown
}

printf '# vimhelp test suite\n'
printf '# root: %s\n' "$ROOT"
printf '# work: %s\n' "$WORK"
printf '\n'

# --- 1. Syntax ---------------------------------------------------------------
sh -n "$ROOT/vimhelp"
check 0 $? "1. sh -n vimhelp"
sh -n "$ROOT/install.sh"
check 0 $? "1. sh -n install.sh"
sh -n "$ROOT/tests/test.sh"
check 0 $? "1. sh -n tests/test.sh"

# --- 2. Fresh install into a temporary HOME ----------------------------------
H2="$WORK/home2"
OUT2="$WORK/out2"
HOME="$H2" sh "$ROOT/install.sh" >"$OUT2" 2>&1
check 0 $? "2. fresh install exits 0"
file_x "$H2/.local/bin/vimhelp" "2. installed command exists and is executable"
"$H2/.local/bin/vimhelp" --help >"$WORK/help2" 2>&1
check 0 $? "2. installed vimhelp --help runs"
contains "$WORK/help2" "Usage: vimhelp" "2. --help prints usage"
contains "$OUT2" "Installed vimhelp" "2. success message printed"

# --- 3. Repeated installation / update ----------------------------------------
OUT3="$WORK/out3"
HOME="$H2" sh "$ROOT/install.sh" >"$OUT3" 2>&1
check 0 $? "3. re-running the installer exits 0"
contains "$OUT3" "updating" "3. existing installation updated in place"
file_x "$H2/.local/bin/vimhelp" "3. command still present after update"

# --- 4. Installation from a local clone (run from elsewhere) ------------------
H4="$WORK/home4"
mkdir -p "$WORK/elsewhere"
OUT4="$WORK/out4"
(cd "$WORK/elsewhere" && HOME="$H4" sh "$ROOT/install.sh") >"$OUT4" 2>&1
check 0 $? "4. clone install works from another directory"
file_x "$H4/.local/bin/vimhelp" "4. clone-installed command exists"
contains "$OUT4" "local repository" "4. local clone copy was used, not a download"

# --- 5. Installer streamed through stdin --------------------------------------
# Streamed via `cat ... | sh` with the clone as CWD: $0 no longer points at
# the script, and the local repository copy next to the working directory is
# used. The network variant (streamed with no local copy => download) is
# covered by test 7 and, after publication, by PUBLISHED=1 below.
H5="$WORK/home5"
OUT5="$WORK/out5"
(cat "$ROOT/install.sh" | (cd "$ROOT" && HOME="$H5" sh)) >"$OUT5" 2>&1
check 0 $? "5. streamed installer (stdin) exits 0"
file_x "$H5/.local/bin/vimhelp" "5. streamed install produced the command"

# --- 6. Destination occupied by an unrelated file ------------------------------
H6="$WORK/home6"
mkdir -p "$H6/.local/bin"
printf '#!/bin/sh\necho UNRELATED TOOL\n' > "$H6/.local/bin/vimhelp"
chmod 700 "$H6/.local/bin/vimhelp"
OUT6="$WORK/out6"
HOME="$H6" sh "$ROOT/install.sh" >"$OUT6" 2>&1
rc6=$?
if [ "$rc6" -ne 0 ]; then ok "6. refuses unrelated destination (non-zero exit)"; else nok "6. refuses unrelated destination (exited 0)"; fi
contains "$OUT6" "not a vimhelp installation" "6. informative refusal message"
if grep -q 'UNRELATED TOOL' "$H6/.local/bin/vimhelp" 2>/dev/null; then
    ok "6. unrelated file left untouched"
else
    nok "6. unrelated file left untouched"
fi

# --- 7a. No downloader available and no local copy ------------------------------
BIN7="$WORK/bin7"
mkdir -p "$BIN7"
for tool in sh dirname mktemp grep rm cat; do
    p="$(command -v "$tool" 2>/dev/null)" && ln -s "$p" "$BIN7/$tool"
done
H7="$WORK/home7"
OUT7="$WORK/out7"
mkdir -p "$WORK/empty7"
(cat "$ROOT/install.sh" | (cd "$WORK/empty7" && env HOME="$H7" PATH="$BIN7" sh)) >"$OUT7" 2>&1
rc7=$?
if [ "$rc7" -ne 0 ]; then ok "7a. fails clearly without a downloader"; else nok "7a. fails clearly without a downloader (exited 0)"; fi
contains "$OUT7" "curl or wget" "7a. error names the missing dependency"
if [ ! -e "$H7/.local/bin/vimhelp" ]; then ok "7a. nothing installed on failure"; else nok "7a. nothing installed on failure"; fi

# --- 7b. Download path behaviour (404 pre-publish / success post-publish) -------
H7B="$WORK/home7b"
OUT7B="$WORK/out7b"
mkdir -p "$WORK/empty7b"
(cat "$ROOT/install.sh" | (cd "$WORK/empty7b" && HOME="$H7B" sh)) >"$OUT7B" 2>&1
rc7b=$?
if [ "${PUBLISHED:-0}" = "1" ]; then
    check 0 $? "7b. published one-line install succeeds (streamed download)"
    file_x "$H7B/.local/bin/vimhelp" "7b. streamed download installed the command"
    "$H7B/.local/bin/vimhelp" --version >"$WORK/ver7b" 2>&1
    check 0 $? "7b. downloaded vimhelp --version runs"
else
    if [ "$rc7b" -ne 0 ]; then ok "7b. fails clearly when download 404s (pre-publish)"; else nok "7b. fails clearly when download 404s"; fi
    contains "$OUT7B" "download failed" "7b. download failure message"
    if [ ! -e "$H7B/.local/bin/vimhelp" ]; then ok "7b. no partial install left behind"; else nok "7b. no partial install left behind"; fi
fi

# --- 8. Permissions and PATH guidance -------------------------------------------
mode8="$(msg_mode "$H2/.local/bin/vimhelp")"
if [ "$mode8" = "755" ]; then ok "8. installed command mode is 755"; else nok "8. installed command mode is 755 (got $mode8)"; fi

H8="$WORK/home8"
OUT8="$WORK/out8"
# PATH deliberately excludes $H8/.local/bin.
HOME="$H8" PATH="/usr/bin:/bin" sh "$ROOT/install.sh" >"$OUT8" 2>&1
check 0 $? "8. install with dest outside PATH exits 0"
contains "$OUT8" "not in your PATH" "8. PATH warning shown when needed"
contains "$OUT8" 'export PATH="$HOME/.local/bin:$PATH"' "8. PATH guidance line shown"

H8C="$WORK/home8c"
OUT8C="$WORK/out8c"
HOME="$H8C" PATH="$H8C/.local/bin:/usr/bin:/bin" sh "$ROOT/install.sh" >"$OUT8C" 2>&1
check 0 $? "8. install with dest already on PATH exits 0"
absent "$OUT8C" "not in your PATH" "8. no PATH warning when dest is on PATH"

# --- summary ---------------------------------------------------------------------
printf '\n'
printf '# passed: %d  failed: %d\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
