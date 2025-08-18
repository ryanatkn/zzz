// Behavior Evaluators - Profile-specific behavior logic
// Contains 4 evaluator functions (hostile, fearful, neutral, friendly)

const std = @import("std");
const Vec2 = @import("../../lib/math/mod.zig").Vec2;
const BehaviorComposer = @import("composer.zig").BehaviorComposer;
const BehaviorType = @import("composer.zig").BehaviorType;
const ProfileConfigs = @import("profiles.zig").ProfileConfigs;
const BehaviorProfile = @import("../behavior_profile.zig").BehaviorProfile;
const constants = @import("../constants.zig");
const behaviors_mod = @import("../../lib/game/behaviors/mod.zig");

// Import individual behavior modules
const chase_behavior = behaviors_mod.chase_behavior;
const flee_behavior = behaviors_mod.flee_behavior;
const wander_behavior = behaviors_mod.wander_behavior;
const return_home_behavior = behaviors_mod.return_home_behavior;

/// Result structure for composed behavior evaluation
pub const ComposedBehaviorResult = struct {
    velocity: Vec2,
    active_behavior: BehaviorType,
    behavior_changed: bool = false,
    
    // Events for hex-specific handling
    detected_target: bool = false,
    lost_target: bool = false,
    started_fleeing: bool = false,
    stopped_fleeing: bool = false,
    
    /// Get color for this behavior and profile (optional helper)
    pub fn getColor(self: ComposedBehaviorResult, profile: BehaviorProfile) @import("../../lib/core/colors.zig").Color {
        return getBehaviorColor(self.active_behavior, profile);
    }
};

/// Context for behavior evaluation - optimized for performance
pub const BehaviorContext = struct {
    unit_pos: Vec2,
    home_pos: Vec2,
    player_pos: ?Vec2,
    player_alive: bool,
    aggro_multiplier: f32,
    dt: f32,
    distance_to_player: f32,
    distance_from_home_sq: f32, // Squared for performance
    
    pub fn init(unit_pos: Vec2, home_pos: Vec2, player_pos: ?Vec2, player_alive: bool, aggro_multiplier: f32, dt: f32) BehaviorContext {
        const distance_to_player = if (player_pos) |pp| unit_pos.sub(pp).length() else std.math.inf(f32);
        const home_offset = unit_pos.sub(home_pos);
        const distance_from_home_sq = home_offset.lengthSquared();
        
        return .{
            .unit_pos = unit_pos,
            .home_pos = home_pos,
            .player_pos = player_pos,
            .player_alive = player_alive,
            .aggro_multiplier = aggro_multiplier,
            .dt = dt,
            .distance_to_player = distance_to_player,
            .distance_from_home_sq = distance_from_home_sq,
        };
    }
};

/// Evaluate behavior for a specific profile using composed modules
pub fn evaluateBehaviorForProfile(composer: *BehaviorComposer, context: BehaviorContext) ComposedBehaviorResult {
    return switch (composer.profile) {
        .hostile => evaluateHostileBehavior(composer, context),
        .fearful => evaluateFearfulBehavior(composer, context),
        .neutral => evaluateNeutralBehavior(composer, context),
        .friendly => evaluateFriendlyBehavior(composer, context),
    };
}

/// Hostile behavior: chase player aggressively, return home when far
fn evaluateHostileBehavior(composer: *BehaviorComposer, context: BehaviorContext) ComposedBehaviorResult {
    var result = ComposedBehaviorResult{
        .velocity = Vec2.ZERO,
        .active_behavior = composer.current_behavior,
    };
    
    // Try chase behavior first
    if (context.player_alive and context.player_pos != null) {
        const chase_result = chase_behavior.evaluateChase(
            context.unit_pos,
            context.player_pos.?,
            context.player_alive,
            &composer.chase_state,
            ProfileConfigs.hostile.chase,
            context.aggro_multiplier,
            context.dt,
        );
        
        if (chase_result.is_chasing) {
            result.velocity = chase_result.velocity;
            result.active_behavior = .chasing;
            result.detected_target = chase_result.detected_target;
            result.lost_target = chase_result.lost_target;
            result.behavior_changed = composer.current_behavior != .chasing;
            composer.current_behavior = .chasing;
            return result;
        }
        
        // Track lost target event
        if (chase_result.lost_target) {
            result.lost_target = true;
        }
    }
    
    // Fall back to return home behavior
    const home_result = return_home_behavior.calculateReturnHomeVelocity(
        context.unit_pos,
        context.home_pos,
        ProfileConfigs.hostile.return_home,
    );
    
    result.velocity = home_result.velocity;
    result.active_behavior = if (home_result.at_home) .idle else .returning_home;
    result.behavior_changed = composer.current_behavior != result.active_behavior;
    composer.current_behavior = result.active_behavior;
    
    return result;
}

/// Fearful behavior: flee from player, return home when safe
fn evaluateFearfulBehavior(composer: *BehaviorComposer, context: BehaviorContext) ComposedBehaviorResult {
    var result = ComposedBehaviorResult{
        .velocity = Vec2.ZERO,
        .active_behavior = composer.current_behavior,
    };
    
    // Try flee behavior first
    if (context.player_alive and context.player_pos != null) {
        const flee_result = flee_behavior.evaluateFlee(
            context.unit_pos,
            context.player_pos.?,
            context.player_alive,
            &composer.flee_state,
            ProfileConfigs.fearful.flee,
            context.aggro_multiplier,
            context.dt,
        );
        
        if (flee_result.is_fleeing) {
            result.velocity = flee_result.velocity;
            result.active_behavior = .fleeing;
            result.started_fleeing = flee_result.started_fleeing;
            result.stopped_fleeing = flee_result.stopped_fleeing;
            result.behavior_changed = composer.current_behavior != .fleeing;
            composer.current_behavior = .fleeing;
            return result;
        }
    }
    
    // Fall back to return home behavior
    const home_result = return_home_behavior.calculateReturnHomeVelocity(
        context.unit_pos,
        context.home_pos,
        ProfileConfigs.fearful.return_home,
    );
    
    result.velocity = home_result.velocity;
    result.active_behavior = if (home_result.at_home) .idle else .returning_home;
    result.behavior_changed = composer.current_behavior != result.active_behavior;
    composer.current_behavior = result.active_behavior;
    
    return result;
}

/// Neutral behavior: wander near home, ignore player completely
fn evaluateNeutralBehavior(composer: *BehaviorComposer, context: BehaviorContext) ComposedBehaviorResult {
    var result = ComposedBehaviorResult{
        .velocity = Vec2.ZERO,
        .active_behavior = composer.current_behavior,
    };
    
    // Check if too far from home - return if needed  
    const home_tolerance_sq = ProfileConfigs.neutral.return_home.home_tolerance_sq;
    if (context.distance_from_home_sq > home_tolerance_sq) {
        const home_result = return_home_behavior.calculateReturnHomeVelocity(
            context.unit_pos,
            context.home_pos,
            ProfileConfigs.neutral.return_home,
        );
        
        result.velocity = home_result.velocity;
        result.active_behavior = .returning_home;
        result.behavior_changed = composer.current_behavior != .returning_home;
        composer.current_behavior = .returning_home;
        return result;
    }
    
    // Use wander behavior for exploration
    const wander_result = wander_behavior.evaluateWander(
        context.unit_pos,
        &composer.wander_state,
        ProfileConfigs.neutral.wander,
        1.0, // speed_multiplier
        context.dt,
    );
    
    result.velocity = wander_result.velocity;
    result.active_behavior = if (wander_result.velocity.lengthSquared() > 0.1) .wandering else .idle;
    result.behavior_changed = composer.current_behavior != result.active_behavior;
    composer.current_behavior = result.active_behavior;
    
    return result;
}

/// Friendly behavior: follow player gently, wander when alone
fn evaluateFriendlyBehavior(composer: *BehaviorComposer, context: BehaviorContext) ComposedBehaviorResult {
    var result = ComposedBehaviorResult{
        .velocity = Vec2.ZERO,
        .active_behavior = composer.current_behavior,
    };
    
    // Try gentle following behavior
    if (context.player_alive and context.player_pos != null) {
        const chase_result = chase_behavior.evaluateChase(
            context.unit_pos,
            context.player_pos.?,
            context.player_alive,
            &composer.chase_state,
            ProfileConfigs.friendly.chase,
            context.aggro_multiplier,
            context.dt,
        );
        
        if (chase_result.is_chasing) {
            result.velocity = chase_result.velocity;
            result.active_behavior = .chasing;
            result.behavior_changed = composer.current_behavior != .chasing;
            composer.current_behavior = .chasing;
            return result;
        }
    }
    
    // Check if too far from home - return if needed
    const home_tolerance_sq = ProfileConfigs.friendly.return_home.home_tolerance_sq;
    if (context.distance_from_home_sq > home_tolerance_sq) {
        const home_result = return_home_behavior.calculateReturnHomeVelocity(
            context.unit_pos,
            context.home_pos,
            ProfileConfigs.friendly.return_home,
        );
        
        result.velocity = home_result.velocity;
        result.active_behavior = .returning_home;
        result.behavior_changed = composer.current_behavior != .returning_home;
        composer.current_behavior = .returning_home;
        return result;
    }
    
    // Use wander behavior for exploration
    const wander_result = wander_behavior.evaluateWander(
        context.unit_pos,
        &composer.wander_state,
        ProfileConfigs.friendly.wander,
        1.0, // speed_multiplier
        context.dt,
    );
    
    result.velocity = wander_result.velocity;
    result.active_behavior = if (wander_result.velocity.lengthSquared() > 0.1) .wandering else .idle;
    result.behavior_changed = composer.current_behavior != result.active_behavior;
    composer.current_behavior = result.active_behavior;
    
    return result;
}

/// Get behavior color for visualization (hex-specific)
pub fn getBehaviorColor(behavior: BehaviorType, profile: BehaviorProfile) @import("../../lib/core/colors.zig").Color {
    // Map BehaviorType to legacy BehaviorState for color compatibility
    const legacy_behavior = switch (behavior) {
        .idle => behaviors_mod.behavior_state_machine.BehaviorState.idle,
        .chasing => behaviors_mod.behavior_state_machine.BehaviorState.chasing,
        .fleeing => behaviors_mod.behavior_state_machine.BehaviorState.fleeing,
        .wandering => behaviors_mod.behavior_state_machine.BehaviorState.idle,
        .returning_home => behaviors_mod.behavior_state_machine.BehaviorState.returning_home,
    };
    
    return constants.getBehaviorColor(legacy_behavior, profile);
}