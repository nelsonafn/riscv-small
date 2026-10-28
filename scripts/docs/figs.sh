#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# figs.sh - render documentation figures from their committed sources.
#
#   scripts/docs/figs.sh            render every source
#   scripts/docs/figs.sh --all      same as above (explicit)
#   scripts/docs/figs.sh --check    fail when a source is newer than its output
#   scripts/docs/figs.sh --png      render WaveDrom PNG previews for review
#   scripts/docs/figs.sh --url      print svg.wavedrom.com preview URLs
#
# Sources and outputs
#   doc/figs/wave/*.json5   ->  doc/figs/wave/*.svg     (wavedrom-cli via npx)
#   doc/figs/*.drawio       ->  doc/figs/*.svg          (drawio CLI, embedded XML)
#
# Frozen figures are never regenerated; list their basenames in FROZEN.
# Environment:
#   WAVEDROM_CLI_VERSION  wavedrom-cli major version to pin (default 3)
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIGS="$ROOT/doc/figs"
WAVE="$FIGS/wave"
FROZEN=("architecture-legacy")
WAVEDROM_CLI_VERSION="${WAVEDROM_CLI_VERSION:-3}"

MODE="all"
for arg in "$@"; do
    case "$arg" in
        --all)      MODE="all" ;;
        --check)    MODE="check" ;;
        --png)      MODE="png" ;;
        --url)      MODE="url" ;;
        -h|--help)  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          echo "figs.sh: unknown option '$arg' (try --help)" >&2; exit 2 ;;
    esac
done

die()  { echo "figs.sh: $*" >&2; exit 1; }
warn() { echo "figs.sh: warning: $*" >&2; }
info() { echo "figs.sh: $*"; }

is_frozen() {
    local base="$1" name
    for name in "${FROZEN[@]}"; do
        [ "$base" = "$name" ] && return 0
    done
    return 1
}

wave_sources() {
    [ -d "$WAVE" ] || return 0
    find "$WAVE" -maxdepth 1 -type f -name '*.json5' | sort
}

drawio_sources() {
    [ -d "$FIGS" ] || return 0
    find "$FIGS" -maxdepth 1 -type f -name '*.drawio' | sort
}

need_npx() {
    command -v npx >/dev/null 2>&1 || die "npx not found; install Node.js to render WaveDrom"
}

need_drawio() {
    command -v drawio >/dev/null 2>&1
}

render_wave() {
    local src="$1" out="${1%.json5}.svg"
    npx -y "wavedrom-cli@${WAVEDROM_CLI_VERSION}" -i "$src" -s "$out" >/dev/null
    info "wave   $src -> $out"
}

render_drawio() {
    local src="$1" out="${1%.drawio}.svg"
    # drawio from a snap cannot write outside $HOME; fail with a clear hint.
    if ! drawio -x -f svg -e -o "$out" "$src" >/dev/null 2>&1; then
        die "drawio failed for $src (snap confinement? try writing inside \$HOME)"
    fi
    info "drawio $src -> $out"
}

check_pairs() {
    local failures=0 src out
    while IFS= read -r src; do
        [ -z "$src" ] && continue
        out="${src%.json5}.svg"
        if [ ! -f "$out" ]; then
            echo "figs.sh: missing output: ${out#$ROOT/}" >&2; failures=$((failures + 1))
        elif [ "$src" -nt "$out" ]; then
            echo "figs.sh: stale output: ${out#$ROOT/} (source is newer)" >&2; failures=$((failures + 1))
        fi
    done < <(wave_sources)

    while IFS= read -r src; do
        [ -z "$src" ] && continue
        is_frozen "$(basename "${src%.drawio}")" && continue
        out="${src%.drawio}.svg"
        if [ ! -f "$out" ]; then
            echo "figs.sh: missing output: ${out#$ROOT/}" >&2; failures=$((failures + 1))
        elif [ "$src" -nt "$out" ]; then
            echo "figs.sh: stale output: ${out#$ROOT/} (source is newer)" >&2; failures=$((failures + 1))
        fi
    done < <(drawio_sources)

    if [ "$failures" -ne 0 ]; then
        echo "figs.sh: $failures figure(s) out of date; run 'make docs-figs'" >&2
        exit 1
    fi
    info "all figures are up to date"
}

render_png() {
    local outdir="${TMPDIR:-/tmp}/riscv-small-wavedrom"
    mkdir -p "$outdir"
    need_npx
    while IFS= read -r src; do
        [ -z "$src" ] && continue
        npx -y "wavedrom-cli@${WAVEDROM_CLI_VERSION}" -i "$src" -p "$outdir/$(basename "${src%.json5}").png" >/dev/null
        info "png    $src -> $outdir/$(basename "${src%.json5}").png"
    done < <(wave_sources)
    info "previews in $outdir"
}

print_urls() {
    local remote owner_repo branch src rel
    remote="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
    [ -n "$remote" ] || die "no 'origin' remote; cannot build preview URLs"
    owner_repo="${remote#*github.com:}"
    owner_repo="${owner_repo#*github.com/}"
    owner_repo="${owner_repo%.git}"
    branch="$(git -C "$ROOT" branch --show-current 2>/dev/null || true)"
    [ -n "$branch" ] || branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
    while IFS= read -r src; do
        [ -z "$src" ] && continue
        rel="${src#$ROOT/}"
        echo "https://svg.wavedrom.com/github/${owner_repo}/${branch}/${rel}"
    done < <(wave_sources)
    info "preview URLs only; the committed .svg is the canonical embed"
}

case "$MODE" in
    check) check_pairs ;;
    png)   render_png ;;
    url)   print_urls ;;
    all)
        if ! wave_sources | grep -q . && ! drawio_sources | grep -q .; then
            info "no figure sources yet (doc/figs/wave/*.json5 or doc/figs/*.drawio)"
            exit 0
        fi
        while IFS= read -r src; do
            [ -z "$src" ] && continue
            need_npx
            render_wave "$src"
        done < <(wave_sources)
        while IFS= read -r src; do
            [ -z "$src" ] && continue
            is_frozen "$(basename "${src%.drawio}")" && { info "skip   $src (frozen)"; continue; }
            if need_drawio; then render_drawio "$src"; else warn "drawio not found; skipping $src"; fi
        done < <(drawio_sources)
        ;;
esac
