# Trilink: Co-Op

Trilink: Co-Op is a two-player cooperative 2.5D puzzle-platformer set in a futuristic gravity research facility. Every level is designed around communication, timing, and teamwork.

> [!NOTE]
> This project is in early development. The repository currently contains the initial Godot project structure, prototype scene, color materials, and environment assets.

## Core Mechanics

- **Rotating gravity:** Gravity changes direction every 30 seconds, forcing both players to adapt to a new orientation.
- **RGB states:** Each player can switch between red, green, and blue.
- **Shared collision:** Players with the same color become solid to each other, allowing them to stand on, push, and support one another.
- **Phasing:** Players with different colors pass through each other, opening up different cooperative solutions.
- **Shared lives:** If either player dies, both players fail and restart the level.

## Planned Features

- LAN co-op with local server hosting
- Multiple controller support
- Pressure plates and moving platforms
- Color terminals and gravity generators
- Lasers, energy doors, and environmental hazards
- Pushable objects and physics-based puzzles
- A final robotic boss encounter combining the campaign's mechanics

## Technology

- [Godot Engine](https://godotengine.org/) 4.7
- Forward Plus renderer
- Jolt Physics

## Getting Started

1. Install Godot 4.7 or a compatible Godot 4 release.
2. Clone this repository.
3. Import `project.godot` through the Godot Project Manager.
4. Open the project in the editor.

## Project Structure

```text
assets/      3D models, materials, and other game assets
scenes/      Godot scenes
scripts/     Gameplay scripts
shaders/     Custom shaders
```

## Credits

- [Scifi Kit by Quaternius](https://poly.pizza/m/b6otgtfVoe), released into the public domain.

Detailed third-party asset credits are stored alongside their respective assets.

## License

No license has been selected for the original project code and content yet. Third-party assets remain subject to the terms documented in their accompanying credit files.
