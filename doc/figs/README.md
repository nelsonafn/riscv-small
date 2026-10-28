# Figures

Figure sources live here; the rendered artefact is committed next to its source. `doc/README.md` indexes every
figure by ID, and this file records how each **non-Mermaid** figure is produced and why it is not Mermaid.

## Conventions

- **Mermaid** is embedded inline in the documents; it has no file here.
- **WaveDrom** sources live in `wave/` as `.json5`; the `.svg` beside each source is committed and embedded with
  `![alt](wave/<name>.svg)`.
- **drawio** is the exception: only when edges must attach to specific ports, the layout is the information, the
  figure exceeds ~12 nodes, or it must be lifted into a slide.
- Generated artefacts are never edited by hand. Regenerate with `make docs-figs` (or `scripts/docs/figs.sh`).

## Inventory

| Source | Artefact | Tool | Status | Used by |
|---|---|---|---|---|
| `architecture-legacy.drawio` | `architecture-legacy.png` | drawio | frozen | none — historical reference |

## Frozen figures

`architecture-legacy` is listed in `FROZEN` inside `scripts/docs/figs.sh` and is never regenerated. It records the
original design-intent view, is **not** 1:1 with the current RTL, and must not be cited as microarchitecture.
A PNG is used instead of an SVG because the vector export is ~843 kB for a file that is never referenced.

## Non-Mermaid justification

| Figure | Why it is not Mermaid |
|---|---|
| `architecture-legacy` | pre-existing drawio file kept for history; not a live document figure |

## Checks

`make docs-check` verifies that every source has an artefact, that every source is listed here, and that no document
embeds a missing image.
