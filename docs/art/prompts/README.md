# Prompt Registry — README

This folder is the versioned, authoritative record of every image prompt used
in BARLOVENTO. It exists so that art stays **coherent across many generations**
and so that any agent can reproduce or extend the art direction.

## Structure

```
prompts/
├── 000-global-style.md      # canonical style tokens (reused everywhere)
├── factions/
│   ├── acero.md             # Armada of Acero identity + asset log
│   ├── vinculados.md        # Vinculados identity + asset log
│   └── marea-libre.md       # Free Tide identity + asset log
└── <future>/                # environments/, ships/, ui/, ... as needed
```

## How to add an asset

1. Open (or create) the relevant prompt file.
2. Write a new prompt block composed of: **global style tokens** (from
   `000-global-style.md`) + **faction/context tokens** + **asset-specific
   description** + **ratio/size**.
3. Generate via `tools/gen-image.sh` (see the image-generation skill).
4. Append a row to the asset log at the bottom of the file:

```
| Asset | File | Ratio | Version | Date | Note |
| --- | --- | --- | --- | --- | --- |
| Acero corvette — starboard profile | assets/ships/acero/corvette.png | 1:1 | v1 | 2026-10-13 | base silhouette |
```

## Rules

- The prompt is the truth; the image is its rendering.
- Never change a faction's look without updating its identity file first.
- Version = the prompt revision. Bump it when the prompt changes; keep old
  prompts as commented history if useful.
- One asset, one prompt, one log row.
