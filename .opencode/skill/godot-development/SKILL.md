---
name: godot-development
description: Use when writing or editing Godot 4.7 GDScript, scenes, or project structure for BARLOVENTO. Covers the required version, coding conventions, and verification commands.
---

# Godot Development (BARLOVENTO)

## Fixed version

Godot **4.7.2-stable** (latest stable as of 2026-10-13). Do **not** use 4.8
dev builds or 3.x. See `docs/TECH.md`.

## Conventions

- **English only** for code, comments, node names, and resources.
- GDScript: `snake_case` functions/variables, `PascalCase` classes/nodes,
  `CONSTANT_CASE` constants, 4-space indentation, `@export` for inspector
  properties.
- No comments unless asked; prefer self-documenting names.
- Use `class_name` for reusable types; keep autoloads/services under
  `scripts/` and register them in `project.godot`.

## Architecture

Two combat phases + a strategic layer, all sharing one Newtonian simulation
core. Proposed autoloads: `Game`, `TurnManager`, `PhysicsSim`, `FleetManager`,
`LoreDB` (see `docs/TECH.md`). Scenes live in `scenes/`; code in `scripts/`.

## Verify your work

```bash
godot --headless --path . --quit      # parses and loads
godot --headless --path . --import    # imports assets
```

Run at least the first after structural changes. Gameplay requires the editor
until an automated test setup exists.
