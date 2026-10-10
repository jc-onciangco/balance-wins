# Balance Wins: project briefing for Claude Code

An ecosystem card battler inspired by Marvel Snap, built in **Godot 4 (GDScript)**. Players build Balanced
ecosystems and try to make their rival's ecosystems Collapse. The full game design lives in
`docs/DESIGN.md` (exported from the design document); treat it as the source of truth for rules and content.

## Core rules (short version)

- Standard match: 3 real-world ecosystems (regions), 6 seasons, nutrients = season number, win 2 of 3.
- Each ecosystem is one line of 3–5 zones per player (Carrying Capacity). Zones give Niche bonuses.
- A line is **Balanced** when: at least 3 species and 3 trophic roles (including a Producer and a consumer),
  Producer biomass ≥ Herbivore biomass ≥ Predator biomass, and the biome requirement is met.
  Support roles (Decomposer, Pollinator, Symbiont, Parasite) count for roles but not the pyramid.
- Year's End: Balanced beats Collapsed; two Balanced lines compare biomass.
- Terms: card = Species, power = Biomass, energy = Nutrients, location = Ecosystem, deck = Community (12),
  draw pile = Seed Bank, hand = Nest, discard = Detritus, On Reveal = Emergence, Ongoing = Adaptation.

## Code map

- `main_menu.tscn`, `collection.tscn`, `game.tscn`: the three screens (UI is built in code).
- `scripts/data/card_library.gd`: every species and token (`_add(...)` lines). Abilities are strings like
  `"symbiosis:Clownfish:2"`.
- `scripts/data/region_library.gd`: regions, zones, climates, requirements, Residents.
- `scripts/core/rules.gd`: pure rules. Biomass is recomputed from scratch in `Rules.recompute`;
  static abilities go in `compute_value`, balance check in `evaluate`.
- `scripts/core/match_manager.gd`: match flow; on-reveal abilities in `_emergence`, Dusk effects in `_dusk`.
- `scripts/core/rival_ai.gd`: greedy AI that simulates placements and scores the board.
- `scripts/core/game_state.gd`: autoload `GameState`, saves the player's Community to `user://community.cfg`.
- `scripts/ui/ui_kit.gd`: shared colors, theme, card view. `game.gd`, `collection.gd`, `main_menu.gd`: screens.

## Conventions

- Keep the rules engine (`scripts/core`, `scripts/data`) free of UI code so it runs headless.
- Tabs for indentation, typed GDScript where practical, one `class_name` per file.
- Content changes (species, regions) go in the libraries, not in UI code.
- Write player-facing text in plain language using the game's ecological terms.

## Testing

Run these after every change. Godot 4.7.2 is installed at `D:/GODOT/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe`
(it is not on PATH; keep `Godot_v4.7.2-stable_win64.exe` in the same folder, the console exe needs it):

```
D:/GODOT/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
D:/GODOT/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/sim.gd        # 200 AI-vs-AI matches, must print errors: 0
D:/GODOT/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/rules_test.gd # focused rule checks, must print 0 failed
D:/GODOT/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/ui_smoke.gd   # plays a match through the UI
D:/GODOT/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/menu_smoke.gd # menu + collection flow
```

## Status

Done: pathogens, merging, seasonal migration, Seed Bank effects, either/or zones, New Zealand, zone hints,
readable tooltips (see README). Small deviation from the design doc: Myxoma Virus spreads to an adjacent host at
Dusk instead of infecting Reproduce offspring.

## Next task candidates (see the Roadmap in docs/DESIGN.md)

1. Natural Selection (Generation at the end of Season 3, Mutation pools per biome) and Endemism.
2. Abiotic tokens and Habitat Expansion and Loss.
3. Human Settlement set (Human, Domestic Dog).
4. Drag-and-drop and animations for reveals, Perish, infection and migration.

Work in small commits, one system at a time, and run all tests (including rules_test.gd) after each.
