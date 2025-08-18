# TODO: Pure Simulation Phase 1 - Faction & Capability System

## Objective
Implement the foundation for faction-based entity relationships and capabilities, enabling:
- Multi-faceted faction tags for emergent behavior
- Faction-based collision resolution (no more player-special-casing)
- Entity capabilities that define what entities can do
- Foundation for future possession mechanics

## Implementation Tasks

### 1. Create Faction System (hex/factions.zig)
```zig
const std = @import("std");

pub const FactionTag = enum {
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

pub const FactionSet = std.EnumSet(FactionTag);

pub const EntityFactions = struct {
    tags: FactionSet,
    
    pub fn init() EntityFactions {
        return .{ .tags = FactionSet.initEmpty() };
    }
    
    pub fn initWithTags(tag_list: []const FactionTag) EntityFactions {
        var factions = init();
        for (tag_list) |tag| {
            factions.tags.insert(tag);
        }
        return factions;
    }
};

pub const FactionRelation = enum {
    allied,       // Will help in combat, share resources
    friendly,     // Won't attack, may interact positively
    neutral,      // Ignores unless provoked  
    suspicious,   // May attack if approached too closely
    hostile,      // Attacks on sight
};

pub fn calculateRelation(from: EntityFactions, to: EntityFactions) FactionRelation {
    // Implement priority-based rules as designed
}
```

### 2. Create Capabilities Component (lib/game/components/capabilities.zig)
```zig
pub const Capabilities = struct {
    // Movement
    can_move: bool = true,
    move_speed: f32 = 100.0,
    
    // Control
    can_be_controlled: bool = false,
    
    // Combat
    can_attack: bool = false,
    attack_damage: f32 = 10.0,
    can_be_damaged: bool = true,
    
    // Interaction
    can_interact: bool = false,
    
    pub fn init() Capabilities {
        return .{};
    }
};
```

### 3. Update Component Module (lib/game/components/mod.zig)
- Add: `pub const Capabilities = @import("capabilities.zig").Capabilities;`

### 4. Create Faction Presets (hex/faction_presets.zig)
```zig
const factions = @import("factions.zig");
const components = @import("../lib/game/components/mod.zig");
const constants = @import("constants.zig");

pub fn getPlayerFactions() factions.EntityFactions {
    return factions.EntityFactions.initWithTags(&.{
        .halfling,        // Default player race
        .kingdom_guard,   // Starting allegiance
    });
}

pub fn getUnitFactions(disposition: Disposition, unit_type: UnitType) factions.EntityFactions {
    return switch (disposition) {
        .friendly => factions.EntityFactions.initWithTags(&.{
            .halfling,
            .kingdom_guard,
        }),
        .hostile => switch (unit_type) {
            .goblin => factions.EntityFactions.initWithTags(&.{
                .goblin,
                .bandit,
                .territorial,
            }),
            .undead => factions.EntityFactions.initWithTags(&.{
                .undead,
                .necromancer_cult,
            }),
            else => factions.EntityFactions.initWithTags(&.{
                .beast,
                .territorial,
            }),
        },
        .fearful => factions.EntityFactions.initWithTags(&.{
            .beast,
            .fleeing,
        }),
        .neutral => factions.EntityFactions.initWithTags(&.{
            .beast,
            .solitary,
        }),
    };
}

pub fn getPlayerCapabilities() components.Capabilities {
    return .{
        .can_move = true,
        .move_speed = constants.PLAYER_SPEED,
        .can_be_controlled = true,
        .can_attack = true,
        .attack_damage = constants.PLAYER_DAMAGE,
        .can_be_damaged = true,
        .can_interact = true,
    };
}

pub fn getUnitCapabilities(disposition: Disposition) components.Capabilities {
    return switch (disposition) {
        .friendly => .{
            .can_move = true,
            .move_speed = 100.0,
            .can_be_controlled = false,
            .can_attack = false,
            .can_be_damaged = true,
            .can_interact = true,
        },
        .hostile => .{
            .can_move = true,
            .move_speed = 100.0,
            .can_be_controlled = false,
            .can_attack = true,
            .attack_damage = 10.0,
            .can_be_damaged = true,
            .can_interact = false,
        },
        .fearful => .{
            .can_move = true,
            .move_speed = 120.0,
            .can_be_controlled = false,
            .can_attack = false,
            .can_be_damaged = true,
            .can_interact = false,
        },
        .neutral => .{
            .can_move = true,
            .move_speed = 80.0,
            .can_be_controlled = false,
            .can_attack = false,
            .can_be_damaged = true,
            .can_interact = true,
        },
    };
}
```

### 5. Update Storage Types (lib/game/storage/player_storage.zig)
Add Capabilities and Factions to PlayerStorage:
```zig
// Add to component arrays
capabilities: [max_entities]Capabilities,
factions: [max_entities]EntityFactions,

// Update addEntity to include new components
// Update component getter/setter methods
```

### 6. Update Storage Types (lib/game/storage/unit_storage.zig)
Add Capabilities and Factions to UnitStorage:
```zig
// Similar updates as PlayerStorage
```

### 7. Update Entity Creation (hex/hex_game.zig)
In `createPlayer()`:
```zig
const faction_presets = @import("faction_presets.zig");

// When creating player
const player_factions = faction_presets.getPlayerFactions();
const player_capabilities = faction_presets.getPlayerCapabilities();
// Add to storage with new components
```

In unit creation:
```zig
// When creating units
const unit_factions = faction_presets.getUnitFactions(disposition, unit_type);
const unit_capabilities = faction_presets.getUnitCapabilities(disposition);
// Add to storage with new components
```

### 8. Update Collision System (hex/physics.zig)
Replace player-specific collision with faction-based:
```zig
const factions = @import("factions.zig");

pub fn checkPlayerUnitCollision(world: *HexGame) bool {
    const player_pos = world.getPlayerPos();
    const player_radius = world.getPlayerRadius();
    const zone_storage = world.getZoneStorage();
    
    // Get player factions
    const player_factions = if (world.player_entity) |player| {
        if (zone_storage.players.getComponent(player, .factions)) |f| f else return false;
    } else return false;
    
    var unit_iter = world.iterateUnitsInCurrentZone();
    while (unit_iter.next()) |entity_id| {
        // Get unit components
        const transform = zone_storage.units.getComponent(entity_id, .transform) orelse continue;
        const health = zone_storage.units.getComponent(entity_id, .health) orelse continue;
        const unit_factions = zone_storage.units.getComponent(entity_id, .factions) orelse continue;
        const capabilities = zone_storage.units.getComponent(entity_id, .capabilities) orelse continue;
        
        if (!health.alive) continue;
        
        // Check physical collision
        if (collision.checkCircleCollision(player_pos, player_radius, transform.pos, transform.radius)) {
            // Check faction relationship
            const relation = factions.calculateRelation(unit_factions, player_factions);
            
            // Only count as collision if hostile/suspicious and can attack
            if ((relation == .hostile or relation == .suspicious) and capabilities.can_attack) {
                return true;
            }
            // Friendly/allied units don't cause damage collision
        }
    }
    return false;
}
```

### 9. Testing Plan
1. Create test zone with mixed faction entities:
   - Friendly halfling guards that follow but don't damage
   - Hostile goblin bandits that attack
   - Neutral beasts that ignore unless provoked
   - Allied entities that help in combat

2. Verify faction relationships:
   - Friendly units follow player without damaging
   - Hostile units attack on sight
   - Neutral units ignore until provoked
   - Faction tags properly influence behavior

3. Performance testing:
   - Ensure 60 FPS maintained
   - Check memory usage with faction components
   - Profile faction relationship calculations

## Success Criteria
- [x] Faction system implemented with multi-faceted tags
- [x] Capabilities component added to entities
- [x] Player and units have appropriate factions
- [x] Collision system uses faction relationships
- [x] Friendly units no longer damage player on contact
- [x] All existing gameplay functionality preserved
- [x] Performance remains at 60 FPS

## Next Steps (Phase 2 Preview)
- Remove player-specific methods (getPlayerPos, setPlayerAlive, etc.)
- Convert player to controllable entity
- Add controller abstraction for possession
- Enable switching control between entities