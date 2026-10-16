# Phoebe Adventures · Godot

[中文](README.zh-CN.md) · [English](README.en.md)

Repository: [GitHub](https://github.com/MrsEWE44/phoebe-adventures-godot)

This is a 2D top-down action-adventure game built with Godot 4.7.2. Explore maps, solve puzzles, unlock characters, collect weapons and items, and survive wave-based encounters while following Phoebe and her friends.

## Current content

- 5 chapters and 47 sub-levels
- Exploration, puzzles, NPC dialogue, chests, wave combat, and boss encounters
- Phoebe, Nuonuo, Kunkun, Q-Bit Penguin, Doro, Gugu Penguin, and Chapter 4/5 characters
- Shared progression, experience crystals, equipment, consumables, weapon upgrades, and inventory
- Chapter weapon pools, character-only weapons, and biome bonuses
- Terrain collision authored as editable Godot scene nodes
- Local saves, save reset, travel scrolls, and defeat/retry flows

## Run the project

1. Install Godot 4.7.2 or a compatible Godot 4.7 build.
2. Install Git LFS with `git lfs install`.
3. Import the root `project.godot` in Godot.
4. Wait for resource import, then run with F6/F5. The entry scene is `Scence/Main.tscn`.

The Windows export preset is in `export_presets.cfg`. Before a release build, reimport assets on the target machine and verify audio, video, and input settings.

## Controls

WASD moves, the mouse aims, left click/J attacks, right click/K uses the current skill, F casts the character ultimate, E interacts, B/I opens the inventory, L opens the journal, M opens the map, G drops a permitted weapon, and Esc pauses or returns to the hub. Q/R/T and 2/3/4/5 use the corresponding consumables or special items.

## Project layout

`Scence/` contains scenes, levels, and progression logic; `Characters/` contains character definitions, animation, and voice resources; `Combat/` contains enemies, drops, chests, items, and shops; `Weapons/` contains the weapon base class and definitions; `Maps/`, `Art/`, `Audio/`, `BGM/`, and `Videos/` contain game assets; `Tests/` contains regression tests; `Docs/` contains project documentation.

The first 17 sub-levels use editable `CollisionPolygon2D` boundaries under `Terrain/FloorBoundary_*`. After changing collision, run `Tests/expedition_routes.gd` to verify that doors, mechanisms, NPCs, chests, and exits remain reachable.

## Saves and privacy

Runtime data is stored in the project-level `Data/` directory, including saves, backups, logs, and audio settings. `Data/` is ignored by Git and player progress is not uploaded. Test scripts use isolated save files under `.godot/`.

## Tests and maintenance

Common checks:

```powershell
python Tools/validate_project.py
godot --headless --path . --script Tests/expedition_routes.gd
godot --headless --path . --script Tests/early_release.gd
```

Suggested repository name: `phoebe-adventures-godot`.

## License and media

Code, configuration, and original assets in this repository are used under the repository maintainer's terms. Confirm the license for third-party characters, music, videos, voice clips, and reference assets before publishing publicly; replace or remove any asset without distribution rights.
