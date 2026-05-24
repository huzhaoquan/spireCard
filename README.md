# Spire Card UI Demo

Godot 4 card-battle prototype inspired by deck-building roguelikes. The project currently focuses on the battle UI loop, map/menu/shop/rest scene flow, generated 2D assets, and basic card interaction feedback.

## Requirements

- Godot 4.5 or compatible Godot 4.x version
- 1920x1080 viewport target

## Run

1. Open this folder in Godot.
2. Run the project from `project.godot`.
3. Main scene: `res://scenes/menu/MainMenu.tscn`.

## Current Features

- Main menu, map, battle, event, shop, rest, and treasure scenes
- Basic battle loop with player turn, enemy turn, victory, and defeat states
- Hand card fan layout, hover animation, drag/release play flow
- Card hover sound effect from `art/audio/card_hover_freesound.wav`
- Attack, defense, energy, block, HP, draw pile, and discard pile UI
- Player/enemy animated sprite sheets and slash VFX
- Generated UI/card/map/battle art assets committed with Godot import metadata

## Project Layout

- `autoload/` global game state
- `scenes/` Godot scene files
- `scripts/` scene and UI scripts
- `art/` runtime art and audio assets
- `assets/` prototype/support assets
- `devPlan/` planning notes and UI feedback

## Git Notes

The repository ignores Godot editor cache files under `.godot/`, root-level loose generated media, spreadsheets, and discarded UI experiment assets. Runtime assets should live under `art/` or `assets/`.

