#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# check_md.sh - consistency checks for the documentation set.
#
#   scripts/docs/check_md.sh            run every check
#   scripts/docs/check_md.sh --verbose  list each check as it runs
#
# Checks (errors):
#   - unbalanced code fences
#   - forbidden diagram fences (```drawio, ```wavedrom)
#   - architecture-beta (not supported on GitHub)
#   - empty image alt text
#   - missing image targets
#   - WaveDrom source without an SVG, drawio source without an SVG or PNG
#   - non-Mermaid figure missing from doc/figs/README.md
#   - duplicate requirement IDs
#   - dangling trace targets
#
# Warnings:
#   - tier-2 Mermaid families (verify the renderer version first)
#   - an SVG under doc/figs/ that no document references
# -----------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT/doc"
VERBOSE=0
[ "${1:-}" = "--verbose" ] && VERBOSE=1

errors=0
warnings=0

err()  { echo "ERROR: $*" >&2; errors=$((errors + 1)); }
warn() { echo "WARN:  $*" >&2; warnings=$((warnings + 1)); }
note() { [ "$VERBOSE" -eq 1 ] && echo "check: $*"; }

rel() { printf '%s' "${1#$ROOT/}"; }

if [ ! -d "$DOC" ]; then
    echo "check_md: no doc/ directory yet; nothing to check"
    exit 0
fi

mapfile -t DOCS < <(find "$DOC" -type f -name '*.md' | sort)
if [ "${#DOCS[@]}" -eq 0 ]; then
    echo "check_md: no Markdown documents yet; nothing to check"
    exit 0
fi

# ---------------------------------------------------------------------------
# 1. Fences: balanced, and no unsupported diagram languages
# ---------------------------------------------------------------------------
note "fence balance and language"
for f in "${DOCS[@]}"; do
    if ! awk '
        BEGIN { open = 0 }
        /^`{3,}/ {
            match($0, /^`+/); len = RLENGTH
            if (open == 0)      { open = len }
            else if (len == open) { open = 0 }
        }
        END { exit (open != 0) }
    ' "$f"; then
        err "$(rel "$f"): unbalanced code fence"
    fi
    if grep -nE '^```(drawio|wavedrom)' "$f" >/dev/null; then
        err "$(rel "$f"): unsupported diagram fence (GitHub renders neither)"
    fi
    if grep -n 'architecture-beta' "$f" >/dev/null; then
        err "$(rel "$f"): architecture-beta is not used in this project"
    fi
    if grep -nE '^[[:space:]]*(block-beta|packet-beta|requirementDiagram)' "$f" >/dev/null; then
        warn "$(rel "$f"): tier-2 Mermaid family; confirm the renderer version first"
    fi
done

# ---------------------------------------------------------------------------
# 2. Images: non-empty alt text, resolvable relative targets
# ---------------------------------------------------------------------------
note "image alt text and targets"
for f in "${DOCS[@]}"; do
    if grep -nE '!\[\]\(' "$f" >/dev/null; then
        err "$(rel "$f"): image with empty alt text"
    fi
    dir="$(dirname "$f")"
    # Only inspect lines outside code fences, with inline code removed:
    # documentation legitimately shows image syntax as an example.
    while IFS= read -r target; do
        [ -z "$target" ] && continue
        case "$target" in
            http://*|https://*|data:*) continue ;;
        esac
        target="${target%%#*}"
        if [ ! -e "$dir/$target" ]; then
            err "$(rel "$f"): missing image target '$target'"
        fi
    done < <(awk '
        /^`{3,}/ {
            match($0, /^`+/); len = RLENGTH
            if (open == 0)        { open = len }
            else if (len == open) { open = 0 }
            next
        }
        open == 0 {
            line = $0
            gsub(/`[^`]*`/, "", line)
            print line
        }
    ' "$f" | grep -oE '!\[[^]]*\]\([^)]+\)' | sed -E 's/^!\[[^]]*\]\(//; s/\)$//')
done

# ---------------------------------------------------------------------------
# 3. Figure sources have rendered artefacts, and are listed in figs/README.md
# ---------------------------------------------------------------------------
note "figure artefacts and index"
FIGS_README="$DOC/figs/README.md"
if [ -d "$DOC/figs" ]; then
    while IFS= read -r src; do
        [ -z "$src" ] && continue
        base="$(basename "$src")"
        out="${src%.json5}.svg"
        [ -f "$out" ] || err "missing rendered figure: $(rel "$out")"
        if [ -f "$FIGS_README" ]; then
            grep -qF "$base" "$FIGS_README" || err "figure not listed in doc/figs/README.md: $base"
        else
            err "doc/figs/README.md is missing"
        fi
    done < <(find "$DOC/figs" -type f -name '*.json5' | sort)

    while IFS= read -r src; do
        [ -z "$src" ] && continue
        base="$(basename "$src")"
        if [ ! -f "${src%.drawio}.svg" ] && [ ! -f "${src%.drawio}.png" ]; then
            err "missing rendered figure for $(rel "$src")"
        fi
        if [ -f "$FIGS_README" ]; then
            grep -qF "$base" "$FIGS_README" || err "figure not listed in doc/figs/README.md: $base"
        fi
    done < <(find "$DOC/figs" -maxdepth 1 -type f -name '*.drawio' | sort)
fi

# ---------------------------------------------------------------------------
# 4. IDs: duplicates, and trace targets that do not exist
# ---------------------------------------------------------------------------
note "requirement IDs"
DEFS="$(mktemp)"; REFS="$(mktemp)"; trap 'rm -f "$DEFS" "$REFS"' EXIT

# Definitions: first cell of a table row, or a BLK heading.
awk '
    /^\|[[:space:]]*(F|FR|NFR|T|G|D)-[0-9][0-9]/ {
        match($0, /\|[[:space:]]*(F|FR|NFR|T|G|D)-[0-9][0-9]/)
        s = substr($0, RSTART + 1); gsub(/[[:space:]|]/, "", s)
        print s
    }
    /^#{1,6}.*BLK-[A-Z]+/ {
        match($0, /BLK-[A-Z]+/); print substr($0, RSTART, RLENGTH)
    }
' "${DOCS[@]}" | sort > "$DEFS"

dups="$(sort "$DEFS" | uniq -d)"
[ -n "$dups" ] && err "duplicate requirement IDs: $(echo "$dups" | tr '\n' ' ')"

# Trace targets: everything after '->' up to the end of the cell.
awk '
    {
        while (match($0, /->[^|]*/)) {
            print substr($0, RSTART + 2, RLENGTH - 2)
            $0 = substr($0, RSTART + RLENGTH)
        }
    }
' "${DOCS[@]}" | grep -oE '(BLK-[A-Z]+|(F|FR|NFR|T|G|D)-[0-9][0-9])' | sort -u > "$REFS"

while IFS= read -r id; do
    [ -z "$id" ] && continue
    grep -qxF "$id" "$DEFS" || err "trace target without a definition: $id"
done < "$REFS"

# ---------------------------------------------------------------------------
# 5. Unreferenced rendered figures (warning only)
# ---------------------------------------------------------------------------
note "unreferenced figures"
if [ -d "$DOC/figs" ]; then
    while IFS= read -r svg; do
        base="$(basename "$svg")"
        grep -qrF "$base" "$DOC" --include='*.md' || warn "unreferenced figure: $(rel "$svg")"
    done < <(find "$DOC/figs" -type f -name '*.svg' | sort)
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "$errors" -ne 0 ]; then
    echo "check_md: $errors error(s), $warnings warning(s)" >&2
    exit 1
fi
echo "check_md: ok ($warnings warning(s))"
