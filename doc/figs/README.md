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
| `wave/t1-load-use-stall.json5` | `wave/t1-load-use-stall.svg` | wavedrom-cli 3, default skin, `hscale: 3` | as-built | `uarch.md` section 7.5 |
| `wave/t2-branch-flush.json5` | `wave/t2-branch-flush.svg` | wavedrom-cli 3, default skin, `hscale: 2` | as-built | `uarch.md` section 7.5 |
| `wave/t3-fetch-stall.json5` | `wave/t3-fetch-stall.svg` | wavedrom-cli 3, default skin, `hscale: 2` | as-built | `uarch.md` section 7.1 |

The three timing figures are **as-built**: each draws the behaviour of `rtl/`, and where the RTL
diverges from `spec.md` the caption names the gap (`G-09` for T3, `G-19` for T1). They are
hand-derived from the enable and flush expressions in `rtl/control.sv`, not captured from a
simulation trace. The `wavedrom-timing` skill fixes no colour configuration, so they use the
documented WaveDrom default skin and differ only in `hscale`.

## Frozen figures

`architecture-legacy` is listed in `FROZEN` inside `scripts/docs/figs.sh` and is never regenerated. It records the
original design-intent view, is **not** 1:1 with the current RTL, and must not be cited as microarchitecture.
A PNG is used instead of an SVG because the vector export is ~843 kB for a file that is never referenced.

## Non-Mermaid justification

| Figure | Why it is not Mermaid |
|---|---|
| `architecture-legacy` | pre-existing drawio file kept for history; not a live document figure |
| `wave/t1-load-use-stall`, `wave/t2-branch-flush`, `wave/t3-fetch-stall` | cycle-level timing: the figure contract reserves WaveDrom for time and Mermaid for structure, so these are not an exception to the rule |

## Checks

`make docs-check` verifies that every source has an artefact, that every source is listed here, and that no document
embeds a missing image.
