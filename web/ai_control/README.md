# AI Control System

Sophisticated autonomous AI controller for the Hex game with story-driven gameplay and intelligent behaviors.

## Features

- **Story-Driven Gameplay**: Multiple narrative scenarios with different playstyles
- **Intelligent Behaviors**: Combat, exploration, stealth, puzzle-solving
- **Low-Latency Control**: ~50ns per command via lock-free ring buffer
- **Modular Architecture**: Clean separation between core, platform, and gameplay

## Quick Start

```bash
# Run the game first
zig build run

# In game, press G to enable AI control

# Run story mode (in another terminal)
npx tsx web/ai_control/demos/story.ts hero

# Or try different scenarios
npx tsx web/ai_control/demos/story.ts speedrun
npx tsx web/ai_control/demos/story.ts pacifist
npx tsx web/ai_control/demos/story.ts warrior
npx tsx web/ai_control/demos/story.ts explorer
```

## Available Scenarios

- **Hero**: Classic hero's journey from start to boss defeat
- **Speedrun**: Optimized path to defeat boss quickly
- **Pacifist**: Complete without combat using stealth and spells
- **Warrior**: Maximum aggression, defeat all enemies
- **Explorer**: Methodical exploration of entire world

## Other Demos

```bash
# Basic movement patterns
npx tsx web/ai_control/demos/movement.ts

# Combat demonstrations
npx tsx web/ai_control/demos/combat.ts

# Test the control system
npx tsx web/ai_control/test.ts
```

## Architecture

```
web/ai_control/
├── core/           # Shared types and base classes
├── node/           # Node.js implementation
├── browser/        # Browser implementation (WebSocket)
├── story/          # Story controller and behaviors
├── demos/          # Demo scripts
└── ui/             # Web UI components
```

## Programmatic Usage

```typescript
import { StoryController } from './web/ai_control';

const controller = new StoryController();
await controller.play('hero', true); // Play hero scenario with narrative
```

## Custom Behaviors

```typescript
import { NodeAIController } from './web/ai_control/node';
import { Behaviors } from './web/ai_control/story/behaviors';

const ai = new NodeAIController();
await ai.connect();

// Use predefined behaviors
const combatActions = Behaviors.combat(enemyPositions, playerPos);
await ai.executeSequence(combatActions);

// Or create custom sequences
await ai.executeSequence([
  { type: 'move', data: { direction: 'right' }, duration: 1000 },
  { type: 'shoot', data: { target: { x: 600, y: 300 }, burst: true }},
  { type: 'spell', data: { slot: 0, target: { x: 400, y: 400 }}},
  { type: 'wait', duration: 500 }
]);

ai.disconnect();
```

## Development

The AI control system uses a memory-mapped file (`.ai_commands`) for ultra-low latency communication between the controller and game. The game polls this buffer every frame when AI control is enabled.

### Protocol

Commands are 32-byte aligned structures:
- `frame` (u32): Target frame for execution
- `keys` (u64): Keyboard state bitfield
- `mouseX/Y` (f32): Mouse position
- `buttons` (u8): Mouse button state

### Adding New Scenarios

1. Add scenario type to `story/scenarios.ts`
2. Implement scenario method in `story/story_controller.ts`
3. Use behaviors from `story/behaviors.ts` or create new ones

## Performance

- Command latency: ~50ns
- Zero allocations during runtime
- Lock-free ring buffer implementation
- 256 command buffer capacity