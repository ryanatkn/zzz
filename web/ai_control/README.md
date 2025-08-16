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
node --experimental-strip-types web/ai_control/demos/story.ts hero

# Or try different scenarios
node --experimental-strip-types web/ai_control/demos/story.ts speedrun
node --experimental-strip-types web/ai_control/demos/story.ts pacifist
node --experimental-strip-types web/ai_control/demos/story.ts warrior
node --experimental-strip-types web/ai_control/demos/story.ts explorer
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
node --experimental-strip-types web/ai_control/demos/movement.ts

# Combat demonstrations
node --experimental-strip-types web/ai_control/demos/combat.ts

# Test the control system
node --experimental-strip-types web/ai_control/test.ts
```

## Using npm Scripts

For convenience, you can also use the provided npm scripts:

```bash
npm run ai:story          # Run story demo (default: hero scenario)
npm run ai:movement       # Run movement patterns demo
npm run ai:combat         # Run combat demo
npm run ai:test          # Run system test
```

To run story scenarios with npm, append `--` followed by the scenario:
```bash
npm run ai:story -- speedrun
npm run ai:story -- pacifist --quiet
```

## Architecture

```
web/ai_control/
├── core/           # Shared types and base classes
├── node/           # Node.js implementation  
├── story/          # Story controller and behaviors
├── demos/          # Demo scripts
├── index.ts        # Main module exports
└── test.ts         # System test utility
```

## Programmatic Usage

```typescript
import { StoryController } from '../story/story_controller.js';

const controller = new StoryController();
await controller.play('hero', true); // Play hero scenario with narrative
```

## Custom Behaviors

```typescript
import { NodeAIController } from '../node/controller.js';
import { Behaviors } from '../story/behaviors.js';

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

## Troubleshooting

### Common Issues

**AI control not working:**
- Make sure to press `G` in the game first to enable AI control mode
- The game must be running before starting any AI controller
- Check that the `.ai_commands` file exists in the game directory

**Node.js errors:**
- Requires Node.js 22+ for `--experimental-strip-types` flag
- For older Node versions, install `tsx` globally: `npm install -g tsx`
- Then use `tsx` instead of `node --experimental-strip-types`

**Import errors:**
- All imports must include `.js` extension for ES modules
- Use relative paths starting with `../` or `./`
- Ensure you're running from the project root directory

**Performance issues:**
- Close other applications using the `.ai_commands` file
- Reduce game graphics settings if experiencing lag
- The AI performs best at 60+ FPS game performance