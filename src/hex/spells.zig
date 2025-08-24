const std = @import("std");
const math = @import("../lib/math/mod.zig");
const GameParticleSystem = @import("../lib/particles/game_particles.zig").GameParticleSystem;
const constants = @import("constants.zig");
const loggers = @import("../lib/debug/loggers.zig");
const world_state_mod = @import("world_state.zig");
const frame = @import("../lib/core/frame.zig");
const game_abilities = @import("../lib/game/abilities/mod.zig");
const effect_manager = game_abilities.effect_manager;
const components = @import("../lib/game/components/mod.zig");
const combat = @import("combat.zig");
const entity_queries = @import("entity_queries.zig");

const Vec2 = math.Vec2;
const ZoneData = world_state_mod.HexGame.ZoneData;
const HexGame = world_state_mod.HexGame;
const EntityId = world_state_mod.EntityId;
const FrameContext = frame.FrameContext;

pub const SpellType = enum {
    None,
    Lull, // Reduce aggro range
    Blink, // Teleport (dungeon only)
    Phase, // Walk through solid objects
    Charm, // Control units
    Lethargy, // Slow enemy movement speed
    Haste, // Movement speed boost
    Multishot, // Fire multiple bullets
    Dazzle, // Area confusion/slow
};

// Use generic spell slot system from lib/game
const SpellSlotSystem = game_abilities.spell_slots.SpellSlotSystem(SpellType, 8);
pub const SpellSlot = game_abilities.spell_slots.SpellSlot(SpellType);

// Hex-specific effect types for the generic effect manager
pub const HexEffectType = enum {
    lull,
    blink_trail,
    phase_state,
    charm_effect,
    shield_aura,
    haste_boost,
    damage_zone,
    heal_zone,
};

// Use generic effect manager for hex effects
const HexEffectManager = effect_manager.EffectManager(HexEffectType, constants.MAX_LULL_EFFECTS);

/// Component-based spell targeting and effects
/// These helper functions enable flexible spell casting based on component composition
const SpellHelpers = struct {
    /// Check if entity has Teleportable component
    pub fn hasTeleportableComponent(entity_id: EntityId, zone: *const ZoneData) bool {
        // Future: Query FlexibleStorage for Teleportable component
        // For now, player is always teleportable
        _ = entity_id;
        _ = zone;
        return true;
    }

    /// Check if entity has Phaseable component
    pub fn hasPhaseableComponent(entity_id: EntityId, zone: *const ZoneData) bool {
        // Future: Query FlexibleStorage for Phaseable component
        _ = entity_id;
        _ = zone;
        return false; // Only specific entities can phase
    }

    /// Check if entity has Charmable component
    pub fn hasCharmableComponent(entity_id: EntityId, zone: *const ZoneData) bool {
        // Future: Query FlexibleStorage for Charmable component
        _ = entity_id;
        _ = zone;
        return true; // Most units can be charmed
    }

    /// Check if entity has Solid component
    pub fn hasSolidComponent(entity_id: EntityId, zone: *const ZoneData) bool {
        // Future: Query FlexibleStorage for Solid component
        _ = entity_id;
        _ = zone;
        return true; // Most terrain is solid
    }

    /// Perform teleportation with component-based validation
    pub fn performTeleport(entity_id: EntityId, from_pos: Vec2, to_pos: Vec2, max_range: f32, zone: *const ZoneData, game: *HexGame) ?Vec2 {
        if (!SpellHelpers.hasTeleportableComponent(entity_id, zone)) {
            return null; // Entity cannot teleport
        }

        // Component-based range validation
        const distance = from_pos.sub(to_pos).length();
        const effective_range = max_range; // Future: get from Teleportable component

        if (distance > effective_range) {
            // Limit teleport distance
            const direction = to_pos.sub(from_pos).normalize();
            return from_pos.add(direction.scale(effective_range));
        }

        // Check for collision if entity doesn't have Phaseable component
        if (!SpellHelpers.hasPhaseableComponent(entity_id, zone)) {
            // Future: Check collision with solid terrain and entities
            // For now, allow teleportation to any location
        }

        _ = game;
        return to_pos;
    }

    /// Check if entity can be affected by charm/lull effects based on components
    pub fn canAffectEntity(entity_id: EntityId, zone: *const ZoneData, effect_type: HexEffectType) bool {
        return switch (effect_type) {
            .lull => {
                // Lull affects any entity that has unit behavior
                // Future: Check for Unit component
                _ = entity_id;
                _ = zone;
                return true;
            },
            else => {
                // Other effects require specific components
                _ = entity_id;
                _ = zone;
                return false;
            },
        };
    }

    /// Apply phase state to entity (makes them non-solid temporarily)
    pub fn applyPhaseState(entity_id: EntityId, duration: f32, zone: *ZoneData) void {
        // Future: Temporarily disable Solid component or add Phase effect
        _ = entity_id;
        _ = duration;
        _ = zone;
    }

    /// Apply charm effect to entity
    pub fn applyCharmEffect(entity_id: EntityId, caster: EntityId, duration: f32, zone: *ZoneData) bool {
        if (!SpellHelpers.hasCharmableComponent(entity_id, zone)) {
            return false;
        }

        // Future: Modify entity's Unit component to follow caster
        // For now, placeholder implementation
        _ = caster;
        _ = duration;
        loggers.getGameLog().info("charm_applied", "Charm effect applied to entity {}", .{entity_id});
        return true;
    }

    /// Validate spell targeting based on physicality and line of sight
    pub fn validateSpellTarget(caster_pos: Vec2, target_pos: Vec2, spell_type: SpellType, zone: *const ZoneData) bool {
        _ = zone; // Future: Use for line of sight checks

        return switch (spell_type) {
            .None => false,

            .Lull => {
                // Area effect spell - always valid (targets ground, not entities)
                return true;
            },

            .Blink => {
                // Teleportation spell - check maximum range
                const distance = caster_pos.sub(target_pos).length();
                return distance <= constants.BLINK_MAX_DISTANCE;
            },

            .Phase => {
                // Self-targeted spell - target position ignored
                return true;
            },

            .Charm => {
                // Targeted spell - check maximum range and line of sight
                const charm_range = 100.0; // Should match castCharmSpell range
                const distance = caster_pos.sub(target_pos).length();
                return distance <= charm_range;
                // Future: Add line of sight check using zone terrain
            },

            else => {
                // Future spells - basic range check
                const max_range = 200.0; // Default maximum spell range
                const distance = caster_pos.sub(target_pos).length();
                return distance <= max_range;
            },
        };
    }

    /// Get spell targeting type for UI feedback
    pub fn getSpellTargetingType(spell_type: SpellType) components.MagicTarget.TargetType {
        return switch (spell_type) {
            .None => .single,
            .Lull => .area,
            .Blink => .single, // Click to teleport to location
            .Phase => .self, // Self-cast only
            .Charm => .single, // Click to target unit
            else => .single,
        };
    }

    /// Check if spell requires line of sight
    pub fn spellRequiresLineOfSight(spell_type: SpellType) bool {
        return switch (spell_type) {
            .None => false,
            .Lull => false, // Area effect doesn't need direct line of sight
            .Blink => false, // Can teleport through walls
            .Phase => false, // Self-cast
            .Charm => true, // Needs to see target to charm
            else => true, // Most spells require line of sight
        };
    }
};

pub const SpellSystem = struct {
    // Use generic spell slot system
    slot_system: SpellSlotSystem,

    // Use generic effect manager for all spell effects
    effect_manager: HexEffectManager,

    pub fn init() SpellSystem {
        var system = SpellSystem{
            .slot_system = SpellSlotSystem.init(),
            .effect_manager = HexEffectManager.init(),
        };

        // Initialize spell slots with specific spells and cooldowns
        system.slot_system.setSpell(0, .Lethargy, getSpellCooldown(.Lethargy)); // Slot 1 (key: 1)
        system.slot_system.setSpell(1, .Haste, getSpellCooldown(.Haste)); // Slot 2 (key: 2)
        system.slot_system.setSpell(2, .Phase, getSpellCooldown(.Phase)); // Slot 3 (key: 3)
        system.slot_system.setSpell(3, .Charm, getSpellCooldown(.Charm)); // Slot 4 (key: 4)
        system.slot_system.setSpell(4, .Lull, getSpellCooldown(.Lull)); // Slot 5 (key: Q)
        system.slot_system.setSpell(5, .Blink, getSpellCooldown(.Blink)); // Slot 6 (key: E)
        system.slot_system.setSpell(6, .Dazzle, getSpellCooldown(.Dazzle)); // Slot 7 (key: R)
        system.slot_system.setSpell(7, .Multishot, getSpellCooldown(.Multishot)); // Slot 8 (key: F)

        return system;
    }

    /// Spell system update function with frame context
    pub fn update(self: *SpellSystem, frame_ctx: FrameContext) void {
        const deltaTime = frame_ctx.effectiveDelta();
        // Update all spell cooldowns using generic system
        self.slot_system.update(deltaTime);

        // Update all spell effects using generic effect manager
        self.effect_manager.updateAll(deltaTime);
    }

    pub fn setActiveSlot(self: *SpellSystem, slot: usize) void {
        self.slot_system.setActiveSlot(slot);
    }

    // Compatibility accessors for existing hex code
    pub fn getSlot(self: *const SpellSystem, slot_index: usize) ?*const SpellSlot {
        return self.slot_system.getSlot(slot_index);
    }

    pub fn getSlotMut(self: *SpellSystem, slot_index: usize) ?*SpellSlot {
        return self.slot_system.getSlotMut(slot_index);
    }

    pub fn getActiveSlot(self: *const SpellSystem) *const SpellSlot {
        return self.slot_system.getActiveSlot();
    }

    pub fn castActiveSpell(self: *SpellSystem, game: *HexGame, zone: *const world_state_mod.HexGame.ZoneData, target_pos: Vec2, effect_system: *GameParticleSystem, self_cast: bool) bool {
        const slot = self.slot_system.getActiveSlotMut();
        if (!slot.canCast()) return false;

        const spell_type = slot.spell_type;

        // Get controlled entity position for spell casting
        const controlled_entity = game.getControlledEntity() orelse return false;
        const controlled_zone = game.getCurrentZone();
        const controlled_transform = controlled_zone.units.getComponent(controlled_entity, .transform) orelse return false;
        const controlled_pos = controlled_transform.pos;

        // Determine actual target based on spell targeting type and self-cast preference
        const targeting_type = SpellHelpers.getSpellTargetingType(spell_type);
        const actual_target = switch (targeting_type) {
            .self => controlled_pos, // Always self-target
            .area, .single => if (self_cast) controlled_pos else target_pos, // Allow both modes
            else => if (self_cast) controlled_pos else target_pos,
        };

        // Validate targeting based on spell physicality
        if (!SpellHelpers.validateSpellTarget(controlled_pos, actual_target, spell_type, zone)) {
            loggers.getGameLog().info("spell_invalid_target", "Invalid target for spell {}", .{spell_type});
            return false;
        }

        const success = self.castSpell(spell_type, game, zone, actual_target, effect_system);
        if (success) {
            slot.startCooldown();
        }
        return success;
    }

    pub fn castSpell(self: *SpellSystem, spell: SpellType, game: *HexGame, zone: *const world_state_mod.HexGame.ZoneData, target_pos: Vec2, effect_system: *GameParticleSystem) bool {
        switch (spell) {
            .None => return false,

            .Lull => return self.castLullSpell(game, target_pos, effect_system),

            .Blink => return self.castBlinkSpell(game, zone, target_pos, effect_system),

            .Phase => return self.castPhaseSpell(game, zone, target_pos, effect_system),

            .Charm => return self.castCharmSpell(game, zone, target_pos, effect_system),

            .Lethargy => return self.castLethargySpell(game, zone, target_pos, effect_system),

            .Haste => return self.castHasteSpell(game, zone, target_pos, effect_system),

            .Multishot => return self.castMultishotSpell(game, zone, target_pos, effect_system),

            .Dazzle => return self.castDazzleSpell(game, zone, target_pos, effect_system),
        }
    }

    /// Apply lull effect to all units in the specified area using component-based queries
    fn applyLullEffectToUnitsInArea(game: *HexGame, center_pos: Vec2, radius: f32, duration: f32, effect_system: *GameParticleSystem) void {
        const zone = game.getCurrentZone();
        const radius_sq = radius * radius;
        var affected_count: u32 = 0;

        // Component-based unit targeting
        for (0..zone.units.count) |i| {
            const entity_id = zone.units.entities[i];
            if (entity_id == std.math.maxInt(u32)) continue;

            const transform = &zone.units.transforms[i];
            const health = &zone.units.healths[i];
            const unit = &zone.units.units[i];

            // Skip if unit is not alive
            if (!health.alive) continue;

            // Check if entity can be affected by lull using component queries
            if (!SpellHelpers.canAffectEntity(entity_id, zone, .lull)) {
                loggers.getGameLog().info("lull_immune", "Entity {} immune to lull effects", .{entity_id});
                continue;
            }

            // Check if unit is within the lull area
            const to_center = transform.pos.sub(center_pos);
            const dist_sq = to_center.lengthSquared();

            if (dist_sq <= radius_sq) {
                // Unit is in area and can be affected - apply lull effect
                unit.aggro_factor = constants.LULL_AGGRO_MULT;
                affected_count += 1;

                // Add visual effect for this unit
                effect_system.addUnitStatusAura(transform.pos, transform.radius, duration);

                loggers.getGameLog().info("lull_unit_affected", "Unit {} at ({d:.0}, {d:.0}) affected by lull - aggro reduced to {d}%", .{ entity_id, transform.pos.x, transform.pos.y, constants.LULL_AGGRO_MULT * 100 });
            }
        }

        loggers.getGameLog().info("lull_effect_complete", "Lull effect applied to {} units in {d}-radius area", .{ affected_count, radius });
    }

    /// Cast Lull spell - reduce unit aggro in area
    fn castLullSpell(self: *SpellSystem, game: *HexGame, target_pos: Vec2, effect_system: *GameParticleSystem) bool {
        // Add lull effect using generic effect manager
        _ = self.effect_manager.addAoEEffect(
            .lull,
            target_pos,
            constants.LULL_RADIUS,
            constants.LULL_DURATION,
            1.0, // Standard intensity
        );

        // Apply lull effect to all units in area using component-based targeting
        applyLullEffectToUnitsInArea(game, target_pos, constants.LULL_RADIUS, constants.LULL_DURATION, effect_system);

        // Add area of effect visual indicator
        effect_system.addLullAreaParticle(target_pos, constants.LULL_RADIUS, constants.LULL_DURATION);

        loggers.getGameLog().info("lull_cast", "Lull cast at ({d:.0}, {d:.0}) - AoE aggro reduction for {d}s", .{ target_pos.x, target_pos.y, constants.LULL_DURATION });
        return true;
    }

    /// Cast Blink spell - teleport to target location
    fn castBlinkSpell(self: *SpellSystem, game: *HexGame, zone: *const ZoneData, target_pos: Vec2, effect_system: *GameParticleSystem) bool {
        // Only works in dungeons (follow camera mode) - future: component-based environment check
        if (zone.camera_mode != constants.CameraMode.follow) {
            loggers.getGameLog().info("blink_dungeon_only", "Blink only works in dungeons", .{});
            return false;
        }

        // Component-based teleportation
        const controlled_entity = game.getControlledEntity() orelse {
            loggers.getGameLog().info("blink_no_controlled_entity", "No controlled entity found", .{});
            return false;
        };

        const player_pos = entity_queries.getEntityPos(game, controlled_entity) orelse {
            loggers.getGameLog().info("blink_no_position", "Could not get controlled entity position", .{});
            return false;
        };

        // Check if entity has Teleportable component
        if (!SpellHelpers.hasTeleportableComponent(controlled_entity, zone)) {
            loggers.getGameLog().info("blink_not_teleportable", "Entity cannot be teleported", .{});
            return false;
        }

        // Perform component-based teleportation with validation
        const final_pos = SpellHelpers.performTeleport(controlled_entity, player_pos, target_pos, constants.BLINK_MAX_DISTANCE, zone, game) orelse {
            loggers.getGameLog().info("blink_invalid_target", "Invalid teleport target", .{});
            return false;
        };

        // Execute teleportation
        entity_queries.setEntityPos(game, controlled_entity, final_pos);

        // Add blink trail effect using effect manager
        _ = self.effect_manager.addInstantEffect(
            .blink_trail,
            player_pos,
            1.0, // Standard intensity
        );

        // Visual effects
        const entity_radius = entity_queries.getEntityRadius(game, controlled_entity) orelse 0.2; // 20cm default radius
        effect_system.addPortalTravelParticle(player_pos, entity_radius);
        loggers.getGameLog().info("blink_teleport", "Blink teleport to {any}", .{final_pos});
        return true;
    }

    /// Cast Phase spell - allow walking through solid objects
    fn castPhaseSpell(self: *SpellSystem, game: *HexGame, zone: *const ZoneData, target_pos: Vec2, effect_system: *GameParticleSystem) bool {
        const controlled_entity = game.getControlledEntity() orelse {
            loggers.getGameLog().info("phase_no_controlled_entity", "No controlled entity found", .{});
            return false;
        };

        const player_pos = entity_queries.getEntityPos(game, controlled_entity) orelse {
            loggers.getGameLog().info("phase_no_position", "Could not get controlled entity position", .{});
            return false;
        };

        // Check if entity has Phaseable component
        if (!SpellHelpers.hasPhaseableComponent(controlled_entity, zone)) {
            loggers.getGameLog().info("phase_not_phaseable", "Entity cannot phase", .{});
            return false;
        }

        // Apply phase state to player
        const phase_duration = constants.PHASE_DURATION;
        // Note: zone parameter would need to be mutable for actual phase state modification
        // For now, just log the phase activation
        loggers.getGameLog().info("phase_applied", "Phase state applied to entity {} for {d}s", .{ controlled_entity, phase_duration });

        // Get controlled entity radius for phase effect
        const current_zone = game.getCurrentZoneConst();
        const controlled_radius = if (current_zone.units.getComponent(controlled_entity, .transform)) |transform|
            transform.radius
        else
            0.7; // Default radius

        // Add phase effect using effect manager
        _ = self.effect_manager.addAoEEffect(
            .phase_state,
            if (target_pos.x == 0 and target_pos.y == 0) player_pos else target_pos,
            controlled_radius * 2, // Phase aura around controlled entity
            phase_duration,
            1.0, // Standard intensity
        );

        // Visual effects - phase shimmer around controlled entity
        effect_system.addUnitStatusAura(player_pos, controlled_radius, phase_duration);
        loggers.getGameLog().info("phase_cast", "Phase activated for {d}s - can walk through walls", .{phase_duration});
        return true;
    }

    /// Cast Lethargy spell - slow target enemy's movement
    fn castLethargySpell(_: *SpellSystem, _: *HexGame, zone: *const ZoneData, target_pos: Vec2, effect_system: *GameParticleSystem) bool {
        // Find closest unit to target position
        const lethargy_range = constants.LETHARGY_RANGE;
        const lethargy_range_sq = lethargy_range * lethargy_range;
        var closest_unit: ?struct { index: usize, distance_sq: f32 } = null;

        for (0..zone.units.count) |i| {
            const entity_id = zone.units.entities[i];
            if (entity_id == std.math.maxInt(u32)) continue;

            const transform = &zone.units.transforms[i];
            const health = &zone.units.healths[i];

            if (!health.alive) continue;

            const to_target = transform.pos.sub(target_pos);
            const dist_sq = to_target.lengthSquared();

            if (dist_sq <= lethargy_range_sq) {
                if (closest_unit == null or dist_sq < closest_unit.?.distance_sq) {
                    closest_unit = .{ .index = i, .distance_sq = dist_sq };
                }
            }
        }

        if (closest_unit == null) {
            loggers.getGameLog().info("lethargy_no_target", "No units within range of target", .{});
            return false;
        }

        // Apply lethargy effect to target unit
        const target_unit = closest_unit.?;
        const zone_mut = @constCast(zone);
        const unit = &zone_mut.units.units[target_unit.index];
        // Reduce aggro range to simulate sluggish unit behavior
        unit.aggro_range = unit.aggro_range * constants.LETHARGY_SPEED_MULT;

        // Visual effect
        const target_transform = &zone.units.transforms[target_unit.index];
        effect_system.addUnitStatusAura(target_transform.pos, target_transform.radius, constants.LETHARGY_DURATION);

        loggers.getGameLog().info("lethargy_cast", "Unit slowed to {d}% speed for {d}s", .{ constants.LETHARGY_SPEED_MULT * 100, constants.LETHARGY_DURATION });
        return true;
    }

    /// Cast Haste spell - boost movement speed
    fn castHasteSpell(_: *SpellSystem, game: *HexGame, _: *const ZoneData, _: Vec2, effect_system: *GameParticleSystem) bool {
        // Get controlled entity for haste effect
        const controlled_entity = game.getControlledEntity() orelse return false;
        const controlled_zone = game.getCurrentZone();
        const controlled_transform = controlled_zone.units.getComponent(controlled_entity, .transform) orelse return false;
        const controlled_pos = controlled_transform.pos;
        const controlled_radius = controlled_transform.radius;

        // In a real implementation, we'd modify controlled entity's speed_mult
        // For now, just add visual effect
        effect_system.addUnitStatusAura(controlled_pos, controlled_radius, constants.HASTE_DURATION);

        loggers.getGameLog().info("haste_cast", "Speed boosted to {d}% for {d}s", .{ constants.HASTE_SPEED_MULT * 100, constants.HASTE_DURATION });
        return true;
    }

    /// Cast Multishot spell - fire multiple projectiles
    fn castMultishotSpell(_: *SpellSystem, game: *HexGame, _: *const ZoneData, target_pos: Vec2, _: *GameParticleSystem) bool {
        // Get controlled entity position for multishot origin
        const controlled_entity = game.getControlledEntity() orelse return false;
        const controlled_zone = game.getCurrentZone();
        const controlled_transform = controlled_zone.units.getComponent(controlled_entity, .transform) orelse return false;
        const controlled_pos = controlled_transform.pos;

        const to_target = target_pos.sub(controlled_pos);
        const base_angle = std.math.atan2(to_target.y, to_target.x);
        const target_distance = to_target.length();

        // Need access to bullet pool - check if enough bullets available
        var bullets_fired: u32 = 0;

        // Fire multiple bullets in a spread pattern
        for (0..constants.MULTISHOT_COUNT) |i| {
            const offset_angle = if (constants.MULTISHOT_COUNT > 1)
                (@as(f32, @floatFromInt(i)) - @as(f32, @floatFromInt(constants.MULTISHOT_COUNT - 1)) / 2.0) * constants.MULTISHOT_SPREAD_ANGLE
            else
                0.0;

            const angle = base_angle + offset_angle;

            // Calculate target position for this bullet based on angle
            const bullet_target = controlled_pos.add(Vec2{
                .x = @cos(angle) * target_distance,
                .y = @sin(angle) * target_distance,
            });

            // Use the hex_game's bullet pool for firing
            if (game.canFireProjectile()) {
                const success = combat.fireProjectile(game, bullet_target, &game.projectile_pool);
                if (success) {
                    bullets_fired += 1;
                } else {
                    // If we can't fire a projectile, stop trying (probably no pool space)
                    break;
                }
            } else {
                // No more bullets available in pool
                break;
            }
        }

        loggers.getGameLog().info("multishot_cast", "Fired {}/{} bullets in spread pattern", .{ bullets_fired, constants.MULTISHOT_COUNT });
        return bullets_fired > 0; // Success if we fired at least one bullet
    }

    /// Cast Dazzle spell - confuse/slow enemies in area
    fn castDazzleSpell(_: *SpellSystem, _: *HexGame, zone: *const ZoneData, target_pos: Vec2, effect_system: *GameParticleSystem) bool {
        // Apply dazzle to all units in area
        const radius_sq = constants.DAZZLE_RADIUS * constants.DAZZLE_RADIUS;
        var affected_count: u32 = 0;

        const zone_mut = @constCast(zone);

        for (0..zone.units.count) |i| {
            const entity_id = zone.units.entities[i];
            if (entity_id == std.math.maxInt(u32)) continue;

            const transform = &zone.units.transforms[i];
            const health = &zone.units.healths[i];
            const unit = &zone_mut.units.units[i];

            if (!health.alive) continue;

            const to_center = transform.pos.sub(target_pos);
            const dist_sq = to_center.lengthSquared();

            if (dist_sq <= radius_sq) {
                // Apply dazzle effect - reduce aggro to simulate confusion
                unit.aggro_range = unit.aggro_range * constants.DAZZLE_SPEED_MULT;
                unit.aggro_factor = constants.DAZZLE_SPEED_MULT;
                affected_count += 1;

                // Visual effect for each affected unit
                effect_system.addUnitStatusAura(transform.pos, transform.radius, constants.DAZZLE_DURATION);
            }
        }

        // Area visual indicator
        effect_system.addLullAreaParticle(target_pos, constants.DAZZLE_RADIUS, constants.DAZZLE_DURATION);

        loggers.getGameLog().info("dazzle_cast", "Dazzled {} units in {d}-radius area", .{ affected_count, constants.DAZZLE_RADIUS });
        return true;
    }

    /// Cast Charm spell - take control of target unit
    fn castCharmSpell(self: *SpellSystem, game: *HexGame, zone: *const ZoneData, target_pos: Vec2, effect_system: *GameParticleSystem) bool {
        const controlled_entity = game.getControlledEntity() orelse {
            loggers.getGameLog().info("charm_no_controlled_entity", "No controlled entity found", .{});
            return false;
        };

        // Find closest unit to target position within charm range
        const charm_range = 100.0; // Charm targeting range
        const charm_range_sq = charm_range * charm_range;
        var closest_unit: ?struct { entity_id: EntityId, index: usize, distance_sq: f32 } = null;

        for (0..zone.units.count) |i| {
            const entity_id = zone.units.entities[i];
            if (entity_id == std.math.maxInt(u32)) continue;

            const transform = &zone.units.transforms[i];
            const health = &zone.units.healths[i];

            // Skip if unit is not alive
            if (!health.alive) continue;

            // Check if entity can be charmed using component queries
            if (!SpellHelpers.hasCharmableComponent(entity_id, zone)) {
                continue;
            }

            // Calculate distance to target position
            const to_target = transform.pos.sub(target_pos);
            const dist_sq = to_target.lengthSquared();

            if (dist_sq <= charm_range_sq) {
                if (closest_unit == null or dist_sq < closest_unit.?.distance_sq) {
                    closest_unit = .{ .entity_id = entity_id, .index = i, .distance_sq = dist_sq };
                }
            }
        }

        if (closest_unit == null) {
            loggers.getGameLog().info("charm_no_target", "No charmable units within range of target", .{});
            return false;
        }

        const target_unit = closest_unit.?;
        const charm_duration = 8.0; // Charm duration in seconds

        // Apply charm effect using component system
        if (!SpellHelpers.applyCharmEffect(target_unit.entity_id, controlled_entity, charm_duration, @constCast(zone))) {
            loggers.getGameLog().info("charm_failed", "Failed to charm unit {}", .{target_unit.entity_id});
            return false;
        }

        // Add charm effect using effect manager
        _ = self.effect_manager.addAoEEffect(
            .charm_effect,
            zone.units.transforms[target_unit.index].pos,
            zone.units.transforms[target_unit.index].radius * 2, // Charm aura around unit
            charm_duration,
            1.0, // Standard intensity
        );

        // Visual effects - charm aura around target unit
        const target_transform = &zone.units.transforms[target_unit.index];
        effect_system.addUnitStatusAura(target_transform.pos, target_transform.radius, charm_duration);

        loggers.getGameLog().info("charm_cast", "Unit {} charmed for {d}s - now under player control", .{ target_unit.entity_id, charm_duration });
        return true;
    }
};

fn getSpellCooldown(spell: SpellType) f32 {
    return switch (spell) {
        .None => 0,
        .Lull => constants.LULL_COOLDOWN,
        .Blink => constants.BLINK_COOLDOWN,
        .Phase => constants.PHASE_COOLDOWN,
        .Charm => constants.CHARM_COOLDOWN,
        .Lethargy => constants.LETHARGY_COOLDOWN,
        .Haste => constants.HASTE_COOLDOWN,
        .Multishot => constants.MULTISHOT_COOLDOWN,
        .Dazzle => constants.DAZZLE_COOLDOWN,
    };
}
