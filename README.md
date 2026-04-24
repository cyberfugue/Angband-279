# Angband-279

This repository contains:

- `angband-2.7.9v6.tar.gz` — original Angband 2.7.9v6 source archive.
- `angband-2.7.9v6/` — extracted original C source tree.
- `Sources/main.swift` — a **native Swift** roguelike implementation inspired by Angband systems (dungeon generation, monsters, FOV, inventory, combat, progression), not a C wrapper.

## Run

```bash
swift run angband279-swift
```

## Controls

- `w`, `a`, `s`, `d`: move / attack adjacent monsters
- `g`: pick up item
- `i`: show inventory summary in the log
- `u`: use healing potion
- `.`: wait a turn
- `?`: show command help in the log
- `q`: quit

## Gameplay loop implemented in Swift

- Procedural room-and-corridor dungeon generation with doors and stairs.
- Turn-based monster AI with pursuit and melee attacks.
- Field-of-view with memory of explored tiles.
- Item spawns, inventory, and consumable healing potions.
- XP gain and player level-ups.
- Multi-depth descent with a win condition at depth 12.
