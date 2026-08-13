# Trilink PvP

Trilink PvP is a two-player LAN-based 2.5D arena fighting game. Two stylized robots battle in a compact sci-fi arena using hand-to-hand combat, RGB color manipulation, wall-mounted spike hazards, knockback, and a mid-round gravity shift.

[Website](https://weasert911.github.io/tri-link/) | [Download for Windows](https://github.com/Weasert911/tri-link/releases/latest/download/Trilink-v0.1.0-windows-x86_64.zip) | [Releases](https://github.com/Weasert911/tri-link/releases)

The game is designed to be immediately readable while creating tactical depth through color matching and positioning. Players must decide when to become vulnerable in order to attack, when to phase through an opponent to escape, and when to trade damage for control of the arena.

> [!NOTE]
> This repository contains the playable vertical slice: local two-player combat, RGB interactions, round flow, presentation effects, menus, settings, controller assignment, and a live AI showcase.

## Core Combat Loop

Each fighter has an HP bar and one active state: red, green, or blue.

- **Matching colors:** Fighters with the same active color are solid to each other. Their attacks, collisions, combos, and knockback can connect.
- **Different colors:** Fighters with different active colors phase through each other. Attacks cannot connect and either player can pass through the other.
- **Color switching:** Players can switch between red, green, and blue during combat. Matching creates an opportunity to attack but also allows the opponent to retaliate.
- **Arena control:** Heavy attacks and combos can push an opponent toward spike traps mounted on the opposing walls.
- **Two win conditions:** A player wins the round by reducing the opponent's HP to zero or knocking them into a spike hazard.
- **Gravity shift:** The arena begins under normal gravity and rotates gravity once during the round, changing movement, orientation, and hazard positioning.

## MVP Scope

- One polished 2.5D sci-fi arena
- Two player-controlled robots using the same base model with distinct player presentation
- Horizontal movement, jumping, aerial control, and dodging
- Red, green, and blue state switching with clear visual feedback
- Color-dependent player collision and attack validation
- HP, damage, hit reactions, knockback, and KO handling
- Basic punches, kicks, jumping attacks, and heavy attacks
- Three to five readable combos, including punch chains, punch-to-kick, a launcher, an aerial follow-up, and heavy knockback
- Spike hazards on the opposing arena walls
- One scripted gravity-shift event per round
- LAN hosting and joining for two players
- Controller support
- Round-based matches with a simple KO and rematch loop

## Design Priorities

1. Make the RGB interaction understandable at a glance.
2. Keep movement and attacks responsive under LAN latency.
3. Make matching colors a deliberate risk instead of a passive damage rule.
4. Keep combos short, readable, and useful for repositioning opponents.
5. Make spike KOs and HP KOs equally viable.
6. Ensure the gravity shift changes strategy without making controls confusing.

## Out of Scope for MVP

- Additional characters or arenas
- Ranked matchmaking or internet relay services
- Large move lists or character-specific combo trees
- Campaign, puzzle, or cooperative modes
- Advanced progression, cosmetics, or unlock systems
- AI opponents

## Technology

- [Godot Engine](https://godotengine.org/) 4.7
- Forward Plus renderer
- Jolt Physics

## Getting Started

1. Install Godot 4.7 or a compatible Godot 4 release.
2. Clone this repository.
3. Import `project.godot` through the Godot Project Manager.
4. Open the project in the editor.

Run the project to open `scenes/main.tscn`. The main menu uses the live arena as its background. Press `F2` to toggle the menu during showcase capture, or `F1` to hide all UI.

## Controls

- Player 1 defaults: `A`/`D`, `Space`, `F`, `X`, `End`, and `1`/`2`/`3`.
- Player 2 defaults: arrow keys, `Enter`, `0`, numpad `7`, numpad `2`, and `7`/`8`/`9`.
- Joypads are assigned in device order and use left stick, `A` jump, `B` roll, `X` light, `Y` heavy, and D-pad RGB switching.
- All keyboard and joypad buttons can be rebound under Settings > Controls.

## Build

Install matching Godot export templates, then run:

```powershell
godot --headless --path . --export-release "Windows Desktop" build/Trilink.exe
```

Settings persist in `user://settings.cfg`. Audio buses are initialized even though this slice does not ship audio assets.

## Tests

Run each SceneTree harness from the repository root:

```powershell
godot --headless --path . --script tests/combat_test.gd
godot --headless --path . --script tests/foundation_test.gd
godot --headless --path . --script tests/flow_test.gd
```

## Project Structure

```text
assets/      3D models, materials, and other game assets
scenes/      Godot scenes
scripts/     Gameplay, flow, feedback, and UI scripts
autoload/    Settings, input, device, and audio services
shaders/     Toon, combat, and menu treatment shaders
```

## Credits

- [Scifi Kit by Quaternius](https://poly.pizza/m/b6otgtfVoe), released into the public domain.

Detailed third-party asset credits are stored alongside their respective assets.

## License

No license has been selected for the original project code and content yet. Third-party assets remain subject to the terms documented in their accompanying credit files.
