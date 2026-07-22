# Super Miranda 3D

Dive into the Storm, ride the rim of a twisting neon tunnel, and try to keep the lanes ahead clear for just long enough to survive.

Super Miranda 3D is the 3D sequel to Miranda: a fast, lane-based arcade shooter inspired by Tempest, but framed as forward motion through a dangerous electric tube. You slide clockwise and anticlockwise around the wall, fire straight down the lane in front of you, and decide when not to shoot so valuable pickups can reach you intact.

The Miranda name is a nod to Shakespeare's *The Tempest*, with the game's Storm carrying that reference into the tunnel itself.

Missed enemies do not just vanish. They can reach the rim and become obstacles in your path, turning the tunnel into a growing hazard field. Speed helps you push forward, but it also makes the next bad decision arrive sooner.

## Current Version

The current build has two playable stages, each with its own enemy pattern and music. Stage 1 keeps the bright guide-line Storm look; Stage 2 strips that back into a darker, more opaque tunnel.

Enemies each have their own job:

- **Flippers** dart into danger lanes.
- **Splitters** burst into two flippers when destroyed.
- **Spikers** retreat ahead of you and seed the wall with spikes.
- **Spikes** turn clean lanes into bad choices.
- **Pulsars** fire lane bolts back toward the rim.
- **Exploders** force target priority before they detonate.

Pickups make firing less automatic:

- **Life** gives you another chance if it reaches you.
- **Purge** clears anchored rim obstacles.
- Shooting a pickup destroys it, so sweeping every lane with fire is not always the best play.

There is also a start screen, pause menu, game-over flow, stage-clear flow, test stage selection, damage flash, camera shake, and short invulnerability after taking a hit.

## Controls

- **Left / Right**: step lanes clockwise or anticlockwise.
- **Up / Down**: adjust travel speed.
- **Space**: fire down the current lane.
- **P**: pause or unpause.
- **R**: restart the selected stage.
- **Enter / Space on menu**: start or restart from the overlay.

## Running

Open the project in Godot 4.4 or newer:

```text
project.godot
```

The main scene is:

```text
res://scenes/storm_preview.tscn
```

This project is configured for the GL Compatibility renderer.

## Project Layout

```text
audio/
  music/       Stage music stems and preview mixes
  sfx/         Player, enemy, stage, and UI sound effects
scenes/
  storm_preview.tscn
scripts/
  pause_menu.gd
  storm_camera.gd
  storm_player.gd
  storm_stage.gd
  storm_tube.gd
```

## License

Unless otherwise noted, the code, procedural art, and audio assets in this repository are licensed under the MIT License. See [LICENSE](LICENSE).
