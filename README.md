# Trilink PvP

Trilink PvP is a two-player LAN-based 2.5D arena fighting game. Two stylized robots battle in a compact sci-fi arena using hand-to-hand combat, RGB color manipulation, wall-mounted spike hazards, knockback, and a mid-round gravity shift.

The game is designed to be immediately readable while creating tactical depth through color matching and positioning. Players must decide when to become vulnerable in order to attack, when to phase through an opponent to escape, and when to trade damage for control of the arena.

> [!NOTE]
> This project is in pre-production. The repository currently contains the Godot project shell, an empty prototype scene, RGB materials, and a sci-fi environment asset kit. The gameplay systems below describe the target MVP and are not implemented yet.

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

There is not yet a playable main scene. Open `scenes/prt_scene.tscn` to inspect the current prototype scene.

## Project Structure

```text
assets/      3D models, materials, and other game assets
scenes/      Godot scenes
scripts/     Gameplay scripts (planned)
shaders/     Custom shaders (planned)
```

## Credits

- [Scifi Kit by Quaternius](https://poly.pizza/m/b6otgtfVoe), released into the public domain.

Detailed third-party asset credits are stored alongside their respective assets.

## License

No license has been selected for the original project code and content yet. Third-party assets remain subject to the terms documented in their accompanying credit files.
