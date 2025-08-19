// Behavior Integration - Main coordination and public API implementation
// Handles composer storage, system lifecycle, and unit update function

const std = @import("std");
const math = @import("../../lib/math/mod.zig");
const frame = @import("../../lib/core/frame.zig");
const hex_game_mod = @import("../hex_game.zig");

const BehaviorComposer = @import("composer.zig").BehaviorComposer;
const Disposition = @import("../disposition.zig").Disposition;
const evaluators = @import("evaluators.zig");
const UnitUpdateContext = @import("context.zig").UnitUpdateContext;

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
}

/// Cleanup behavior composer system
pub fn deinitBehaviorSystem() void {
    composer_storage.deinit();
}

/// Get or create behavior composer for an entity
fn getOrCreateComposer(entity_id: u32, profile: Disposition, home_pos: Vec2) *BehaviorComposer {
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

/// Simplified unit update function using context struct - full update including visuals
pub fn updateUnit(context: UnitUpdateContext) void {
    const result = evaluateUnitBehavior(context);
    applyBehaviorResult(context, result);
}

/// Evaluate unit behavior without applying any changes - pure function
pub fn evaluateUnitBehavior(context: UnitUpdateContext) evaluators.ComposedBehaviorResult {
    const profile = context.unit.disposition;

    // Get behavior composer for this entity
    const composer = getOrCreateComposer(context.unit.entity_id, profile, context.unit.homePos());

    // Create context for behavior evaluation
    const behavior_context = evaluators.BehaviorContext.init(
        context.transform.pos,
        context.unit.homePos(),
        if (context.player_alive) context.player_pos else null,
        context.player_alive,
        context.unit.aggro_factor,
        context.frame_ctx.effectiveDelta(),
    );

    // Evaluate composed behavior (pure function)
    return evaluators.evaluateBehaviorForProfile(composer, behavior_context);
}

/// Apply behavior result to unit components - caller controls what gets updated
pub fn applyBehaviorResult(context: UnitUpdateContext, result: evaluators.ComposedBehaviorResult) void {
    const dt = context.frame_ctx.effectiveDelta();

    // Apply movement
    context.transform.vel = result.velocity;
    context.transform.pos = context.transform.pos.add(result.velocity.scale(dt));

    // Apply visual color (caller can override this by calling evaluateUnitBehavior directly)
    context.visual.color = result.getColor(context.unit.disposition);
}

/// Legacy function for backward compatibility - will be removed
pub fn updateUnitWithAggroMod(
    unit_comp: *Unit,
    transform: *Transform,
    visual: *Visual,
    player_pos: Vec2,
    player_alive: bool,
    aggro_multiplier: f32,
    frame_ctx: FrameContext,
) void {
    _ = aggro_multiplier; // Legacy parameter, now using unit's aggro_factor
    updateUnit(UnitUpdateContext.init(unit_comp, transform, visual, player_pos, player_alive, frame_ctx));
}
