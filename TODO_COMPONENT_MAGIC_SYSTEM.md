# TODO: Component-Based Magic & Terrain System

## Vision
Transform the current type-based system into a flexible component composition architecture that enables emergent gameplay through component interactions. Focus on gesture-friendly, non-elemental magic that leverages mouse control.

## Core Design Principles

### 1. Component Composition Over Types
- **Current**: Entities have fixed types (pit, wall, altar) that determine behavior
- **Target**: Entities are compositions of components that define all behaviors
- **Benefit**: Any entity can gain/lose any behavior dynamically

### 2. Mouse-Gesture Magic System
- **Philosophy**: Magic should feel fluid and natural with mouse control
- **Implementation**: Click for targeted, Ctrl+click for self-cast, drag for directional
- **Focus**: Non-elemental, tactical magic over damage dealing

## Component Architecture

### Terrain Components (Decomposed)

#### Physical Properties
```zig
// Instead of Terrain.solid field
pub const Solid = struct {
    passable_with_phase: bool = true,  // Can phase spell bypass?
};

// Instead of Terrain.blocks_sight
pub const Opaque = struct {
    transparency: f32 = 0.0,  // 0 = fully opaque, 1 = fully transparent
};

// Surface properties for movement
pub const Surface = struct {
    friction: f32 = 1.0,      // 1.0 = normal, 0.1 = ice, 2.0 = sticky
    walkable: bool = true,
    climbable: bool = false,
};
```

#### Behavioral Components
- Use existing `Hazard` - damage/death on contact
- Use existing `Awakeable` - terrain that can come alive
- Use existing `Interactable` - can be activated/used
- Add `Mutable` - can change state (ice melts, doors open)
- Add `Controllable` - can be commanded/charmed

### Magic System Components

#### Core Magic Components
```zig
pub const Phaseable = struct {
    phased: bool = false,
    phase_duration: f32 = 0,
    original_solid: ?*Solid = null,  // Store original collision state
};

pub const Charmable = struct {
    charmed: bool = false,
    original_controller: EntityId = INVALID_ENTITY,
    charm_duration: f32 = 0,
    charm_strength: f32 = 1.0,  // Resistance factor
};

pub const Teleportable = struct {
    can_blink: bool = true,
    blink_range: f32 = 200,
    last_blink_time: f32 = 0,
};

pub const MagicTarget = struct {
    targetable: bool = true,
    self_castable: bool = true,
    area_radius: f32 = 0,  // 0 = single target, >0 = AoE
};
```

## Spell Implementations

### 1. Blink (Teleport)
**Components Required**: `Transform`, `Teleportable`
**Cast**: Click location within range
**Effect**: Instant position change, brief invulnerability
```
Query: Entities with Transform + Teleportable
Action: Update Transform.pos to mouse position
Visual: Fade out/in effect at both positions
```

### 2. Lull (Reduce Aggro)
**Components Required**: `Unit`, `Effects`
**Cast**: Click enemy or Ctrl+click for AoE around player
**Effect**: Reduces aggro_range and aggro_factor temporarily
```
Query: Entities with Unit + Effects in radius
Action: Add aggro_mult modifier to Effects
Visual: Calming particle effect
```

### 3. Phase (Ethereal Form)
**Components Required**: `Transform`, `Phaseable`, `Visual`
**Cast**: Ctrl+click self or click ally
**Effect**: Pass through solids, immunity to physical damage
```
Query: Target with Phaseable component
Action: Set phased=true, temporarily remove Solid component
Visual: Translucent effect, ghostly particles
```

### 4. Charm/Command
**Components Required**: `Unit`, `Charmable`, `Movement`
**Cast**: Click enemy to charm, then click to command movement
**Effect**: Take control of enemy unit temporarily
```
Query: Target with Unit + Charmable
Action: Swap controller, add player input handler
Visual: Glowing eyes, control beam from player
```

### 5. Area Effect Magic
**Components Required**: Varies by spell
**Cast**: Click for center or Ctrl+click for self-centered
**Effect**: Applies to all valid targets in radius
```
Query: All entities with required components in radius
Action: Apply spell effect to each
Visual: Expanding ring or persistent area indicator
```

## Implementation Plan

### Phase 1: Component Decomposition ✅
- [x] Create components directory structure
- [x] Extract individual components
- [x] Add Hazard component
- [ ] Decompose Terrain into Solid, Opaque, Surface

### Phase 2: Flexible Storage
- [ ] Create FlexibleStorage that can hold any component combination
- [ ] Implement efficient component queries
- [ ] Add runtime component add/remove operations

### Phase 3: Core Magic Components
- [ ] Implement Phaseable component
- [ ] Implement Charmable component  
- [ ] Implement Teleportable component
- [ ] Implement MagicTarget component

### Phase 4: Spell System Integration
- [ ] Update spell system to use component queries
- [ ] Implement Blink spell
- [ ] Implement enhanced Lull (already exists, needs component integration)
- [ ] Implement Phase spell
- [ ] Implement Charm/Command spell

### Phase 5: Gesture System
- [ ] Standardize mouse gestures (click, ctrl+click, drag)
- [ ] Add gesture recognition for spell casting
- [ ] Visual feedback for gesture states

## Benefits of This Approach

### Gameplay Benefits
- **Emergent Interactions**: Phase through walls, charm awakened terrain
- **Tactical Depth**: Control enemies, manipulate environment
- **Intuitive Controls**: Mouse-gesture based casting feels natural

### Technical Benefits  
- **No Special Cases**: Everything uses same component system
- **Runtime Flexibility**: Add/remove behaviors dynamically
- **Easy Extensions**: New spells just query different components
- **Clean Architecture**: Components define behavior, not types

## Example: Dynamic Terrain

**Mimic Door** (starts as normal door, awakens into creature):
```
Initial: Transform + Visual + Solid + Opaque + Awakeable
Triggered: Remove Solid + Opaque, Add Unit + Health + Movement
Result: Door becomes creature that can be charmed/lulled
```

**Phase-able Wall** (solid wall that phase spell can bypass):
```
Components: Transform + Visual + Solid + Opaque + Phaseable
Phase Active: Solid.passable_with_phase checked by movement system
Result: Phased players pass through, others blocked
```

## Success Criteria

1. **Component Purity**: No type checking, only component queries
2. **Spell Flexibility**: Any valid target can be affected by any applicable spell
3. **Gesture Fluidity**: All spells castable with simple mouse gestures
4. **System Unity**: Terrain, units, and players use same component system

## Next Steps

1. Review and approve this design
2. Start with Phase 2 (Flexible Storage) as foundation
3. Implement one spell end-to-end as proof of concept
4. Iterate based on gameplay feel

---

*This design prioritizes gameplay flexibility and clean architecture while keeping implementation scope manageable. The focus on non-elemental, gesture-based magic creates unique tactical opportunities without adding complex damage type systems.*