# TODO: Pure Simulation Architecture

## Objective
Refactor the game to separate world simulation from player control, enabling:
- Autonomous world simulation without a "player"
- Unit possession/control switching
- Multiple control sources (player, AI, network, replay)
- Clean collision semantics (friendly units don't kill on contact)

## Current Problems
1. **Player-centric architecture**: Hardcoded player checks throughout codebase
2. **Special-case collision**: `checkPlayerUnitCollision()` treats player specially
3. **Rigid control**: Can't watch simulation run autonomously
4. **Possession blocked**: Architecture prevents controlling other entities
5. **Fixed dispositions**: Current system assumes player is always "good" - doesn't support taking on enemy perspectives

## Proposed Architecture: Capability-Based Entities with Input Sources

### Core Concepts

#### 1. Multi-Faceted Faction System (Emergent Allegiances)
Entities can belong to multiple factions, creating emergent relationships:
```zig
const FactionTag = enum {
    // Being type tags (what kind of being you are)
    halfling,
    gnome,
    elf,
    dwarf,
    goblin,
    fey,
    beast,
    elemental,
    golem,
    
    // Being state tags (living/non-living nature)
    living,        // Normal living being
    undead,        // Reanimated being, hostile to living
    construct,     // Never-alive being (golems, elementals)
    
    // Allegiance tags (who you serve)
    kingdom_guard,
    bandit,
    merchant_guild,
    forest_warden,
    necromancer_cult,
    
    // Behavioral tags (how you act)
    territorial,
    pack_hunter,
    solitary,
    trader,
    guardian,
    
    // Modifier tags (magical effects)
    corrupted,     // Twisted by dark magic
    blessed,       // Protected by divine magic
    
    // State tags (temporary, can change)
    charmed,
    enraged,
    fleeing,
    defending_home,
};

const FactionSet = std.EnumSet(FactionTag);

// Entities have multiple faction tags
const EntityFactions = struct {
    tags: FactionSet,
    
    // Examples:
    // Wolf: {beast, living, pack_hunter, territorial}
    // Goblin Bandit: {goblin, living, bandit, territorial}
    // Elf Ranger: {elf, living, forest_warden, guardian}
    // Stone Golem: {golem, construct, guardian, territorial}
    // Undead Dwarf: {dwarf, undead, necromancer_cult}
    // Charmed Guard: {halfling, living, kingdom_guard, charmed}
};

// Faction relationships use tag combinations
fn calculateRelation(entity_a: EntityFactions, entity_b: EntityFactions) FactionRelation {
    // Priority-based rules (highest priority wins):
    
    // 1. Charmed entities are friendly to their charmer's faction
    if (entity_a.tags.contains(.charmed) and sharesCharmerFaction(entity_a, entity_b)) {
        return .allied;
    }
    
    // 2. Undead are hostile to all living things (unless same cult)
    if (entity_a.tags.contains(.undead) and !entity_b.tags.contains(.undead)) {
        if (!sharesCult(entity_a, entity_b)) return .hostile;
    }
    
    // 3. Pack hunters are allied with their pack
    if (entity_a.tags.contains(.pack_hunter) and entity_b.tags.contains(.pack_hunter)) {
        if (sharesRace(entity_a, entity_b)) return .allied;
    }
    
    // 4. Guards vs bandits are always hostile
    if (entity_a.tags.contains(.kingdom_guard) and entity_b.tags.contains(.bandit)) {
        return .hostile;
    }
    
    // 5. Merchants are friendly to most (unless bandit)
    if (entity_a.tags.contains(.merchant_guild)) {
        if (entity_b.tags.contains(.bandit)) return .suspicious;
        return .friendly;
    }
    
    // 6. Territorial creatures are suspicious of others in their territory
    if (entity_a.tags.contains(.territorial) and inTerritory(entity_a, entity_b)) {
        return .suspicious;
    }
    
    // Default based on shared tags
    const shared_count = entity_a.tags.intersectWith(entity_b.tags).count();
    if (shared_count >= 2) return .friendly;
    if (shared_count == 1) return .neutral;
    return .suspicious;
}

const FactionRelation = enum {
    allied,       // Will help in combat, share resources
    friendly,     // Won't attack, may interact positively  
    neutral,      // Ignores unless provoked
    suspicious,   // May attack if approached too closely
    hostile,      // Attacks on sight
};
```

#### 2. Entity Capabilities
Every entity has capabilities defining what it can do:
```zig
const Capabilities = struct {
    // Movement
    can_move: bool = true,
    move_speed: f32 = 100.0,
    
    // Control
    can_be_controlled: bool = false,  // Can player/AI control this?
    
    // Combat
    can_attack: bool = false,
    attack_damage: f32 = 10.0,
    can_be_damaged: bool = true,
    
    // Interaction
    can_interact: bool = false,  // Can be talked to, traded with, etc.
};
```

#### 3. Autonomous Entities
All entities run autonomously by default:
```zig
const Entity = struct {
    // Core identity
    entity_id: EntityId,
    entity_type: EntityType,
    capabilities: Capabilities,
    factions: EntityFactions,  // Multi-faceted faction tags
    
    // Simulation state
    transform: Transform,
    health: Health,
    visual: Visual,
    
    // Autonomous behavior
    autonomy: AutonomyBehavior,  // AI behavior when not controlled
    
    // Optional external control
    controller: ?*Controller = null,
};
```

#### 4. Controllers as Overlays
Controllers inject input without being part of the entity. When you possess an entity, you inherit its faction tags and see the world through its perspective:
```zig
const Controller = struct {
    pub const ControllerType = enum {
        player,
        ai_script,
        network,
        replay,
    };
    
    controller_type: ControllerType,
    input_source: *InputSource,
    target_entity: ?EntityId,
    
    fn update(self: *Controller, world: *World) void {
        if (self.target_entity) |entity_id| {
            if (world.getEntity(entity_id)) |entity| {
                if (entity.capabilities.can_be_controlled) {
                    entity.controller = self;
                }
            }
        }
    }
    
    // When possessing, inherit the entity's faction perspective
    fn getPossessedFactions(self: *Controller, world: *World) ?EntityFactions {
        if (self.target_entity) |entity_id| {
            if (world.getEntity(entity_id)) |entity| {
                return entity.factions;
            }
        }
        return null;
    }
};
```

#### 5. Faction-Based Collision System
No special player collision checks - all based on faction relationships:
```zig
fn updateCollisions(world: *World) void {
    // Check all entity pairs
    for (world.entities, 0..) |entity_a, i| {
        for (world.entities[i+1..], i+1..) |entity_b, j| {
            if (checkCollision(entity_a, entity_b)) {
                resolveCollision(entity_a, entity_b);
            }
        }
    }
}

fn resolveCollision(a: *Entity, b: *Entity) void {
    // Use faction relationships to determine collision outcome
    const relation_a_to_b = calculateRelation(a.factions, b.factions);
    const relation_b_to_a = calculateRelation(b.factions, a.factions);
    
    // Apply collision based on relationship
    switch (relation_a_to_b) {
        .hostile, .suspicious => {
            if (a.capabilities.can_attack) {
                applyDamage(b, a.capabilities.attack_damage);
            }
        },
        .allied, .friendly => {
            // No damage, maybe healing or buffs
        },
        .neutral => {
            // Just physics collision, no damage
            separateEntities(a, b);
        },
    }
    
    // Symmetric check for b->a
    switch (relation_b_to_a) {
        .hostile, .suspicious => {
            if (b.capabilities.can_attack) {
                applyDamage(a, b.capabilities.attack_damage);
            }
        },
        // etc...
    }
}
```

## Implementation Plan

### Phase 1: Faction & Capability System (Foundation)
1. Create FactionTag enum and FactionSet in hex/factions.zig
2. Add EntityFactions component to track multi-faceted tags
3. Add Capabilities struct to lib/game/components
4. Create faction relationship calculator
5. Initialize entities with appropriate faction tags
6. Update collision to check faction relationships instead of hardcoded player checks

### Phase 2: Decouple Player from Simulation
1. Convert player to regular entity with `can_be_controlled = true`
2. Remove `getPlayerPos()`, `setPlayerAlive()` etc.
3. Replace with `getControlledEntity()` or entity queries
4. Update physics.zig to remove player-specific collision

### Phase 3: Controller System
1. Create Controller abstraction
2. Move input handling from player.zig to controller
3. Support switching controlled entity
4. Add "release control" to watch autonomous simulation

### Phase 4: Symmetric Collision
1. Implement capability-based collision resolution
2. Remove all player-specific collision checks
3. Test with various disposition combinations
4. Verify friendly units are harmless

### Phase 5: Advanced Features (Future)
1. Multiple simultaneous controllers
2. Replay system using recorded inputs
3. Network play with remote controllers
4. Spectator mode with free camera

## Migration Strategy

### Step 1: Minimal Fix (Immediate)
```zig
// Quick fix in physics.zig to unblock friendly units
pub fn checkPlayerUnitCollision(world: *HexGame) bool {
    // ...existing code...
    while (unit_iter.next()) |entity_id| {
        // ADD: Skip friendly units
        if (zone_storage.units.getComponent(entity_id, .unit)) |unit| {
            if (unit.disposition == .friendly) continue;
        }
        // ...rest of collision check...
    }
}
```

### Step 2: Gradual Refactoring
- Start with capability system
- Gradually replace player-specific code
- Test each phase thoroughly
- Keep game playable throughout

## Benefits

1. **Semantic Clarity**: Entities interact based on properties, not identity
2. **Flexibility**: Control any entity, watch autonomous battles
3. **Testability**: Deterministic simulation without player input
4. **Extensibility**: Easy to add network play, replays, complex AI
5. **Clean Code**: No special cases, symmetric interactions

## Success Criteria

- [ ] Game runs with no controlled entity (pure simulation)
- [ ] Can switch control between entities at runtime
- [ ] Friendly units follow but don't damage
- [ ] All collision logic is symmetric
- [ ] No hardcoded "player" checks remain
- [ ] AI control system works with any entity
- [ ] Performance remains at 60 FPS

## Notes

- Start with Phase 1-2 to establish foundation
- Phase 3-4 complete the pure simulation goal
- Phase 5 enables advanced features
- Keep each phase independently testable
- Prioritize maintaining game stability during migration
