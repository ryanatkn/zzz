# Game Design

## Zone System

Zones combine environmental properties with entity storage, creating a unified world structure:

- **Travel Metaphor:** Players travel between zones via portals (not "scene changes")
- **Environmental Properties:** Each zone has its own camera mode, scale, and visual settings
- **Entity Storage:** Zones own their entities, simplifying lifetime management
- **Camera Modes:** 
  - **Fixed:** Shows entire world with adjustable zoom (overworld)
  - **Follow:** Tracks player position (dungeons)
- **Persistent State:** Lifestone attunement persists across sessions
- **Movement Bounds:** Camera-aware boundaries in fixed mode only

### Zone Configuration

Zones are data-driven via ZON files (`game_data.zon`):
- Define zone properties (size, camera mode, spawn points)
- Configure entity spawns and behaviors
- Set environmental hazards and obstacles
- Specify portal connections

## Combat System

### Projectile Mechanics
- **Projectile Pool:** 6 projectiles maximum, shared resource
- **Recharge Rate:** 2 projectiles per second automatic recharge
- **Shooting Modes:**
  - **Rhythm Mode:** Hold button for 150ms interval shots
  - **Burst Mode:** Click for immediate shots
- **Projectile Lifetime:** 4-second maximum travel time
- **Damage:** 1 damage per projectile (upgradeable)

### Combat Strategy
- Resource management: Balance burst damage vs sustained fire
- Positioning: Account for projectile travel time
- Crowd control: Use spells to manage multiple enemies

### Future Upgrades
- Multi-shot patterns
- Damage increases
- Range extensions
- Piercing projectiles
- Elemental effects

## Spell System

### Core Mechanics
- **8 Spell Slots:** Mapped to keyboard keys
  - Slots 1-4: Number keys 1-4
  - Slots 5-8: Q, E, R, F keys
- **Targeting System:**
  - **Targeted Cast:** Click location for area effects
  - **Self-Cast:** Ctrl+click for centered effects
- **Cooldown System:** Per-spell independent cooldowns
- **Visual Feedback:** Area indicators show exact effect zones

### Current Spells

#### Lull (Slot 1)
- **Effect:** Reduces unit aggro to 20% for 12 seconds
- **Radius:** 150 units area of effect
- **Cooldown:** 5 seconds
- **Strategy:** Crowd control, escape tool

#### Blink (Slot 2)
- **Effect:** Instant teleport to target location
- **Range:** 200 units maximum
- **Cooldown:** 3 seconds
- **Restriction:** Dungeon zones only
- **Strategy:** Positioning, dodging, exploration

### Spell Design Philosophy
- **Visual Clarity:** Clear area indicators and effect zones
- **Strategic Depth:** Each spell has multiple use cases
- **Resource Management:** Cooldowns force tactical decisions
- **Synergy:** Spells complement combat mechanics

## Effects System

### Visual Effects
- **Particle Pool:** 256 simultaneous effects maximum
- **Effect Types:**
  - Area of effect circles (spells)
  - Impact particles (projectiles)
  - Ambient effects (portals, lifestones)
- **Performance:** Additive blending for GPU efficiency
- **Lifecycle:** Automatic cleanup after duration

### Gameplay Integration
- Effects have gameplay impact (damage, buffs, debuffs)
- Visual feedback matches mechanical effects
- Consistent color coding:
  - Purple: Player spells
  - Blue: Beneficial effects
  - Red: Damage/danger
  - Green: Healing/safety

## Entity System

### Unit Types
- **Player:** Controlled character with full abilities
- **Units:** AI-controlled entities (neutral/friendly/hostile)
- **Behaviors:**
  - Chase: Pursue and attack player
  - Patrol: Follow waypoints
  - Guard: Defend position
  - Flee: Avoid player

### AI Behavior
- **Aggro System:** 
  - Base aggro radius per unit type
  - Modified by player actions and spells
  - Visual feedback (bright = aggro, dim = passive)
- **State Machine:**
  - Idle → Alert → Combat → Return
  - Smooth transitions with visual cues

## World Elements

### Interactive Objects
- **Portals:** Zone travel points (purple circles)
- **Lifestones:** Respawn checkpoints (cyan circles)
- **Obstacles:** Solid barriers (green rectangles)
- **Hazards:** Deadly areas (orange rectangles)

### Persistence
- **Lifestone Binding:** Last touched lifestone becomes respawn point
- **Zone State:** Units respawn on zone reset
- **Save System:** Automatic checkpoint saves

## Progression Systems

### Character Development
- **Health:** Base 3 HP (upgradeable)
- **Movement Speed:** Variable with modifiers
- **Combat Stats:** Damage, fire rate, projectile speed

### Upgrade Paths (Planned)
- **Offensive:** Damage, multi-shot, piercing
- **Defensive:** Health, armor, regeneration
- **Utility:** Movement speed, resource capacity
- **Magic:** Spell power, cooldown reduction

## Game Modes

### Story Mode
- Linear progression through zones
- Narrative elements via environment
- Boss encounters at zone boundaries

### Arena Mode (Planned)
- Wave-based survival
- Score attack challenges
- Leaderboard integration

### Creative Mode (Planned)
- Zone editor
- Entity placement
- Behavior scripting

## Balance Philosophy

- **Skill Over Stats:** Player skill matters more than upgrades
- **Multiple Solutions:** Every challenge has multiple approaches
- **Risk/Reward:** Higher risk strategies offer greater rewards
- **Accessibility:** Core game playable without perfect execution