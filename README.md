# Zzz

> ⚠️ AI slop code and docs, is unstable and full of lies

Zzz is a GUI in Zig written by Claude Code and designed by people.
For the companion CLI see [zz](https://github.com/ryanatkn/zz).

> **status**: [vibe-engineered](./docs/vibe-engineering.md) slop level 1

## Quick start

```bash
# Check Zig version
zig version  # Requires 0.14.1+

# Build and run the Hex demo (shaders compile automatically)
zig build run
```

## What it does

Zzz is a graphics and media programming environment.
It builds on SDL3 and reinvents the rest in Zig.
It treats the web as a backwards compat target and strives for optimal UX and DX.

## What's inside

- **GPU-accelerated graphics** with SDL3, procedural generation, no texture assets
- **Reactive UI system** - UI system in Zig inspired by Svelte 5 and Solid
- **Pure Zig font rendering** - TTF parsing and rasterization without external deps
- **AI control interface** - Memory-mapped automation for testing and demos
- **Zone-based world** - Travel between areas with persistent state
- **Hex demo game** - Fully playable action RPG reference implementation

For technical architecture details, see [CLAUDE.md](./CLAUDE.md)

## Hex demo controls

### Movement
- **WASD**: direct movement
- **Shift + Move**: walk mode (slower)
- **Ctrl + Left-click**: move to mouse position

### Combat
- **Left-click**: fire bullets (burst/rhythm mode)
  - hold for automatic rhythm shooting
  - click for burst shots
  - 6-bullet pool with 2/sec recharge
- **Right-click**: cast active spell at target
- **Ctrl + Right-click**: self-cast active spell

### Spells
- **Number Keys 1-4**: select spell slots 1-4
- **Q, E, R, F**: select spell slots 5-8
  - **Slot 1 - Lull**: reduces enemy aggro by 80% in target area (12s)
  - **Slot 2 - Blink**: teleport to location (dungeon only)

### System
- **Space**: pause/unpause game
- **R**: respawn when dead
- **T**: reset current zone units
- **Y**: full game reset
- **G**: toggle AI control mode
- **Backtick (`)**: toggle transparent HUD overlay
- **ESC**: quit game
- **Mouse Wheel**: zoom in/out

### Visual elements
- **Blue Circle**: player character
- **Red Circles**: enemy units (bright = aggro, dim = passive)
- **Green Rectangles**: solid obstacles
- **Orange Rectangles**: deadly hazards
- **Purple Circles**: zone portals
- **Cyan Circles**: lifestone checkpoints
- **Purple/Blue Areas**: spell effect zones

## Project structure

For technical docs and development guidelines, see **[CLAUDE.md](./CLAUDE.md)**.

## Documentation

- **For developers:** See [CLAUDE.md](./CLAUDE.md) for technical documentation
- **Architecture:** [docs/architecture.md](./docs/architecture.md)
- **Engine library:** [src/lib/README.md](./src/lib/README.md)
- **AI control:** [web/ai_control/README.md](./web/ai_control/README.md)

## Building from source

```bash
# Standard workflow
zig build              # build the game
zig build run          # build and run

# Shader compilation
zig build shaders          # compile shaders only
zig build clean-shaders    # clean rebuild all shaders

# Cross-compilation
zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast  # Windows release
zig build -Doptimize=ReleaseFast                          # native release
```

## AI Control

The game includes a high-performance AI control system for external automation. Press `G` in-game to enable AI control, then run story-driven scenarios with different playstyles.

See **[web/ai_control/README.md](./web/ai_control/README.md)** for complete documentation and demos.

## Creating new applications

Zzz provides a complete engine for games and interactive applications. To create your own:

1. Create a directory in `src/yourapp/`
2. Import engine capabilities from `src/lib/`
3. Follow the Hex game as a reference implementation
4. Add your executable to `build.zig`

See [CLAUDE.md](./CLAUDE.md) for detailed development guidelines.

## Contributing

Issues and discussions and **deleted code** are all very welcome!
PRs are encouraged for concrete discussion, 
but I will probably re-implement rather than merge
most code additions for various reasons (including security).

Not every PR needs an issue but it's usually
preferred to reference one or more issues and discussions.

## License

[Unlicense](./license) (public domain)

## Credits

Built with (see [./deps](./deps)):
- [Zig](https://ziglang.org/) - systems programming language
- [SDL3](https://libsdl.org/) - cross-platform GPU API
- [SDL_shadercross](https://github.com/libsdl-org/SDL_shadercross) - shader compilation
- [Claude Code](https://claude.ai/code) - AI-assisted development, thank you Anthropic people
