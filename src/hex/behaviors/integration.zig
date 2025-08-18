// Behavior Integration - Main coordination and public API implementation
// Handles composer storage, system lifecycle, and unit update function

const std = @import("std");
const math = @import("../../lib/math/mod.zig");
const frame = @import("../../lib/core/frame.zig");
const hex_game_mod = @import("../hex_game.zig");

const BehaviorComposer = @import("composer.zig").BehaviorComposer;
const BehaviorProfile = hex_game_mod.BehaviorProfile;
const evaluators = @import("evaluators.zig");
const entity_mapping = @import("entity_mapping.zig");

const Vec2 = math.Vec2;
const Unit = hex_game_mod.Unit;
const Transform = hex_game_mod.Transform;
const Visual = hex_game_mod.Visual;
const FrameContext = frame.FrameContext;

/// Behavior composer storage - hex-specific extension to generic Unit component
/// This allows hex to use the modular system while keeping lib/game generic
const ComposerHashMap = std.HashMap(u32, BehaviorComposer, std.hash_map.AutoContext(u32), std.hash_map.default_max_load_percentage);
var composer_storage: ComposerHashMap = undefined;
var composer_allocator: std.mem.Allocator = undefined;

/// Initialize behavior composer system
pub fn initBehaviorSystem(allocator: std.mem.Allocator) void {
    composer_allocator = allocator;
    composer_storage = ComposerHashMap.init(allocator);
    entity_mapping.initEntityIDMapping(allocator);
}

/// Cleanup behavior composer system
pub fn deinitBehaviorSystem() void {
    composer_storage.deinit();
    entity_mapping.deinitEntityIDMapping();
}

/// Get or create behavior composer for an entity
fn getOrCreateComposer(entity_id: u32, profile: BehaviorProfile, home_pos: Vec2) *BehaviorComposer {
    const result = composer_storage.getOrPut(entity_id) catch {
        // Fallback: return a default composer (should rarely happen)
        var default_composer = BehaviorComposer.init(profile, home_pos);
        return &default_composer;
    };
    
    if (!result.found_existing) {
        // Create new composer for this entity
        result.value_ptr.* = BehaviorComposer.init(profile, home_pos);
    } else {
        // Update profile if it changed
        if (result.value_ptr.profile != profile) {
            result.value_ptr.profile = profile;
            result.value_ptr.reset(home_pos);
        }
    }
    
    return result.value_ptr;
}

/// Remove behavior composer for an entity (cleanup)
pub fn removeComposer(entity_id: u32) void {
    _ = composer_storage.remove(entity_id);
}

/// New modular unit update function using composed behaviors
pub fn updateUnitWithAggroMod(
    unit_comp: *Unit,
    transform: *Transform,
    visual: *Visual,
    player_pos: Vec2,
    player_alive: bool,
    aggro_multiplier: f32,
    frame_ctx: FrameContext,
) void {
    const entity_id = entity_mapping.getEntityID(unit_comp);
    updateUnitWithAggroModComposed(
        entity_id,
        unit_comp,
        transform,
        visual,
        player_pos,
        player_alive,
        aggro_multiplier,
        frame_ctx,
    );
}

/// Internal function using composed behaviors
fn updateUnitWithAggroModComposed(
    entity_id: u32,
    unit_comp: *Unit,
    transform: *Transform,
    visual: *Visual,
    player_pos: Vec2,
    player_alive: bool,
    aggro_multiplier: f32,
    frame_ctx: FrameContext,
) void {
    const dt = frame_ctx.effectiveDelta();
    const profile = unit_comp.behavior_profile;
    
    // Get behavior composer for this entity
    const composer = getOrCreateComposer(entity_id, profile, unit_comp.home_pos);
    
    // Create context for behavior evaluation
    const context = evaluators.BehaviorContext.init(
        transform.pos,
        unit_comp.home_pos,
        if (player_alive) player_pos else null,
        player_alive,
        aggro_multiplier,
        dt,
    );
    
    // Evaluate composed behavior
    const result = evaluators.evaluateBehaviorForProfile(composer, context);
    
    // Apply hex-specific colors based on active behavior
    visual.color = evaluators.getBehaviorColor(result.active_behavior, profile);
    
    // Apply movement
    transform.vel = result.velocity;
    transform.pos = transform.pos.add(result.velocity.scale(dt));
}