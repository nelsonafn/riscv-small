#!/usr/bin/env bash
# =============================================================================
# scripts/verify/spike/build_spike.sh - build the Spike ISS out of the source tree.
#
# WP-9 P3. Spike is the external reference model: it executes the same ELF as the
# DUT and, with --log-commits, prints one line per retired instruction. Without
# --enable-commitlog the binary has no --log-commits and the whole WP is moot, so
# the configure flag and the verification of the flag are both here, not in the
# caller's head.
#
# The source is `src/riscv-isa-sim` (checked out as a submodule by the caller);
# the build is `build/spike/` (gitignored) so nothing generated lands in the
# source tree.
#
# Two facts measured on this machine (2026-11-17) that the flags encode:
#
#   1. `spike --version` does not exist in this build. The identity is the
#      submodule commit plus the first line of `--help`
#      ("Spike RISC-V ISA Simulator 1.1.1-dev"); both go to build/spike/version.txt.
#
#   2. `-m0:<size>` collides with two built-in devices: the debug module at
#      [0x0, 0x1000) and the device-tree ROM at [0x1000, 0x2000). `--no-dm` and
#      `--disable-dtb` remove them. The CLINT stays at [0x2000000, 0x200c000),
#      so the memory region must end below 0x2000000; the default here is 256 KiB,
#      the same window as the testbench's memory model, which keeps the comparison
#      like-for-like. The ELF does not need re-linking.
#
# Usage: scripts/verify/spike/build_spike.sh [--check]
#   --check   verify an existing build instead of building it
# =============================================================================

set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SRC="$ROOT/src/riscv-isa-sim"
BUILD="$ROOT/build/spike"
PREFIX="$BUILD/install"
SPIKE="$PREFIX/bin/spike"
JOBS=${JOBS:-$(nproc)}

# The invocation every gate must use. Keep in sync with spike_trace.cmake.
SPIKE_ISA="rv32i"
SPIKE_MEM="-m0:0x40000"          # 256 KiB at 0: below the CLINT, same as the TB model
SPIKE_FLAGS="--no-dm --disable-dtb"

# The reference may not float. A comparison against "whatever master was that
# day" cannot be reproduced from this repository, so the source is checked out at
# this exact commit and the build is rejected if it is not there. Bump it
# deliberately, with the traces re-measured in the same change.
SPIKE_REPO="git@github.com:riscv-software-src/riscv-isa-sim.git"
SPIKE_COMMIT="118480991eb16c6a6f40b94fdc35acc9da2ceacd"
# The softfloat submodule that commit pins. Recorded but previously unchecked, so
# a nested checkout could drift without any gate noticing. No rv32i trace uses a
# float opcode, which is exactly why the drift would stay invisible.
SOFTFLOAT_COMMIT="07ebd29db0cfb55723a79fbbffe99103ef38e305"

check_build() {
    [ -x "$SPIKE" ] || { echo "spike: missing $SPIKE (run scripts/verify/spike/build_spike.sh)"; return 1; }
    "$SPIKE" --help 2>&1 | grep -q -- '--log-commits' || {
        echo "spike: built without --enable-commitlog; --log-commits is unavailable"
        return 1
    }
    # Identity, not presence: a trace compared against an unknown Spike is not
    # evidence. There is no --version in this build, so the recorded commit is it.
    local built
    built=$(sed -n 's/^commit=//p' "$BUILD/version.txt" 2>/dev/null | head -1)
    if [ -z "$built" ]; then
        echo "spike: $BUILD/version.txt records no commit; rebuild with scripts/verify/spike/build_spike.sh"
        return 1
    fi
    if [ "$built" != "$SPIKE_COMMIT" ]; then
        echo "spike: built from $built, expected $SPIKE_COMMIT -- rebuild with scripts/verify/spike/build_spike.sh"
        return 1
    fi
    echo "spike: $("$SPIKE" --help 2>&1 | head -1)"
    echo "spike: commit=$built (pinned)"
    local sf
    sf=$(sed -n 's/^softfloat=//p' "$BUILD/version.txt" 2>/dev/null | head -1)
    if [ "$sf" != "$SOFTFLOAT_COMMIT" ]; then
        echo "spike: softfloat ${sf:-<unrecorded>}, expected $SOFTFLOAT_COMMIT -- rebuild with scripts/verify/spike/build_spike.sh"
        return 1
    fi
    echo "spike: softfloat=$sf (pinned)"
    return 0
}

if [ "${1:-}" = "--check" ]; then
    check_build
    exit $?
fi

# --- 1. source ---------------------------------------------------------------
# `-d "$SRC/.git"` would be wrong: a registered submodule has `.git` as a FILE
# (`gitdir: ../../.git/modules/...`), so `-d` is false on a fresh clone and the
# script would clone onto the existing checkout and fail. Ask git instead, which
# answers for a directory, a submodule and a worktree alike.
if ! git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1; then
    echo "spike: cloning into $SRC"
    git clone "$SPIKE_REPO" "$SRC" || exit 1
fi

# Pin the checkout. `git rev-parse` is compared first so a correct tree is not
# re-checked out on every run (the script is called with --check in hot paths).
CURRENT=$(git -C "$SRC" rev-parse HEAD 2>/dev/null || true)
if [ "$CURRENT" != "$SPIKE_COMMIT" ]; then
    echo "spike: pinning $SRC at $SPIKE_COMMIT (was ${CURRENT:-unknown})"
    git -C "$SRC" fetch --depth 1 origin "$SPIKE_COMMIT" 2>/dev/null \
        || git -C "$SRC" fetch origin || exit 1
    git -C "$SRC" checkout --detach "$SPIKE_COMMIT" || exit 1
fi

# berkeley-softfloat-3 is a submodule. A shallow or non-recursive clone leaves the
# build failing on `softfloat/../berkeley-softfloat-3/source/include/softfloat.h`
# with an error that does not mention submodules, so it is repaired here.
git -C "$SRC" submodule update --init --recursive || exit 1

# --- 2. configure and build out of tree --------------------------------------
mkdir -p "$BUILD" || exit 1
cd "$BUILD" || exit 1
if [ ! -f Makefile ]; then
    [ -x "$SRC/configure" ] || ( cd "$SRC" && autoconf ) || exit 1
    echo "spike: configure --prefix=$PREFIX --enable-commitlog"
    "$SRC/configure" --prefix="$PREFIX" --enable-commitlog || exit 1
fi
echo "spike: make -j$JOBS"
make -j"$JOBS" || exit 1
make install || exit 1

# --- 3. identity (there is no --version) -------------------------------------
{
    echo "repository=$SPIKE_REPO"
    echo "commit=$(git -C "$SRC" rev-parse HEAD)"
    echo "softfloat=$(git -C "$SRC/berkeley-softfloat-3" rev-parse HEAD 2>/dev/null)"
    echo "banner=$("$SPIKE" --help 2>&1 | head -1)"
    echo "flags=$SPIKE_FLAGS --isa=$SPIKE_ISA $SPIKE_MEM"
    echo "built=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > version.txt

# --- 4. gate: the flag exists and a real image passes at address 0 -----------
check_build || exit 1

ELF="$ROOT/build/sanity_tests/isa/rv32ui-p-add"
if [ -f "$ELF" ]; then
    # shellcheck disable=SC2086
    "$SPIKE" $SPIKE_FLAGS $SPIKE_MEM --isa="$SPIKE_ISA" "$ELF"
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "spike: rv32ui-p-add exited $rc (expected 0: tohost=1)"
        exit 1
    fi
    echo "spike: rv32ui-p-add passed (tohost=1, exit 0)"
else
    echo "spike: $ELF not built yet; run 'make sanity' for the end-to-end check"
fi
