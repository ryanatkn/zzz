const std = @import("std");
const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");
const hex_game_mod = @import("hex_game.zig");
const frame = @import("../lib/core/frame.zig");
const behaviors_mod = @import("../lib/game/behaviors/mod.zig");

// Import individual behavior modules
const chase_behavior = behaviors_mod.chase_behavior;
const flee_behavior = behaviors_mod.flee_behavior;
const wander_behavior = behaviors_mod.wander_behavior;
const return_home_behavior = behaviors_mod.return_home_behavior;

const Vec2 = math.Vec2;
const Unit = hex_game_mod.Unit;
const Transform = hex_game_mod.Transform;
const Visual = hex_game_mod.Visual;
const FrameContext = frame.FrameContext;

// Import BehaviorProfile from hex_game.zig to avoid circular dependency
const BehaviorProfile = hex_game_mod.BehaviorProfile;

// Modular behavior system - hex composes using lib/game modules
// Each profile uses specific combinations of behavior modules
// State is stored in BehaviorComposer per unit

/// Comprehensive behavior state container for modular system
/// Each unit owns a BehaviorComposer that manages individual behavior states
const BehaviorComposer = struct {
    // Individual behavior states
    chase_state: chase_behavior.ChaseState,
    flee_state: flee_behavior.FleeState,
    wander_state: wander_behavior.WanderState,
    
    // Profile-specific configurations (shared across units)
    profile: BehaviorProfile,
    current_behavior: BehaviorType,
    
    pub fn init(profile: BehaviorProfile, home_pos: Vec2) BehaviorComposer {
        return .{
            .chase_state = chase_behavior.ChaseState.init(),
            .flee_state = flee_behavior.FleeState.init(),
            .wander_state = wander_behavior.WanderState.init(home_pos, @intCast(std.time.milliTimestamp())),
            .profile = profile,
            .current_behavior = .idle,
        };
    }
    
    pub fn reset(self: *BehaviorComposer, home_pos: Vec2) void {
        self.chase_state.reset();
        self.flee_state.reset();
        // Wander state needs re-init for new home position
        self.wander_state = wander_behavior.WanderState.init(home_pos, @intCast(std.time.milliTimestamp()));
        self.current_behavior = .idle;
    }
};

/// Behavior types for tracking active behavior
const BehaviorType = enum {
    idle,
    chasing,
    fleeing,
    patrolling,
    wandering,
    returning_home,
    guarding,
};

/// Profile-specific behavior configurations
/// Each profile defines which behaviors it uses and their parameters
const ProfileConfigs = struct {
    // Hostile profile: aggressive chaser
    const hostile = struct {
        const chase = chase_behavior.ChaseConfig.init(
            constants.UNIT_DETECTION_RADIUS, // detection_range
            5.0, // min_distance - get close to player
            150.0, // chase_speed - fast pursuit
            0.0, // chase_duration - no timer needed
            1.15, // lose_range_multiplier - slight tolerance
        );
        const return_home = return_home_behavior.ReturnHomeConfig.init(
            20.0, // home_tolerance
            100.0, // return_speed
        );
    };
    
    // Fearful profile: flees early and fast
    const fearful = struct {
        const flee = flee_behavior.FleeConfig.init(
            constants.UNIT_DETECTION_RADIUS * 1.2, // danger_range - detect early
            200.0, // safe_distance - flee far
            200.0, // flee_speed - very fast escape
            0.0, // flee_duration - no timer
        );
        const return_home = return_home_behavior.ReturnHomeConfig.init(
            15.0, // home_tolerance - tight home area
            120.0, // return_speed - quick return
        );
    };
    
    // Neutral profile: ignores player, wanders near home
    const neutral = struct {
        const wander = wander_behavior.WanderConfig.init(
            80.0, // wander_speed - leisurely
            50.0, // wander_radius - close to home
            4.0, // direction_change_interval
        );
        const return_home = return_home_behavior.ReturnHomeConfig.init(
            25.0, // home_tolerance - moderate area
            100.0, // return_speed
        );
    };
    
    // Friendly profile: follows player gently
    const friendly = struct {
        const chase = chase_behavior.ChaseConfig.init(
            constants.UNIT_DETECTION_RADIUS * 0.8, // detection_range - moderate
            15.0, // min_distance - don't crowd player
            100.0, // chase_speed - gentle following
            0.0, // chase_duration
            1.2, // lose_range_multiplier - give space
        );
        const wander = wander_behavior.WanderConfig.init(
            60.0, // wander_speed - slow wandering
            80.0, // wander_radius - can explore
            5.0, // direction_change_interval - patient
        );
        const return_home = return_home_behavior.ReturnHomeConfig.init(
            30.0, // home_tolerance - relaxed area
            90.0, // return_speed
        );
    };
};

/// Result structure for composed behavior evaluation
const ComposedBehaviorResult = struct {
    velocity: Vec2,
    active_behavior: BehaviorType,
    behavior_changed: bool = false,
    
    // Events for hex-specific handling
    detected_target: bool = false,
    lost_target: bool = false,
    started_fleeing: bool = false,
    stopped_fleeing: bool = false,
};

/// Context for behavior evaluation - similar to BehaviorContext but hex-specific
const BehaviorContext = struct {
    unit_pos: Vec2,
    home_pos: Vec2,
    player_pos: ?Vec2,
    player_alive: bool,
    aggro_multiplier: f32,
    dt: f32,
    distance_to_player: f32,
    distance_from_home: f32,
    
    pub fn init(unit_pos: Vec2, home_pos: Vec2, player_pos: ?Vec2, player_alive: bool, aggro_multiplier: f32, dt: f32) BehaviorContext {
        const distance_to_player = if (player_pos) |pp| unit_pos.sub(pp).length() else std.math.inf(f32);
        const distance_from_home = unit_pos.sub(home_pos).length();
        
        return .{
            .unit_pos = unit_pos,
            .home_pos = home_pos,
            .player_pos = player_pos,
            .player_alive = player_alive,
            .aggro_multiplier = aggro_multiplier,
            .dt = dt,
            .distance_to_player = distance_to_player,
            .distance_from_home = distance_from_home,
        };
    }
};

/// Evaluate behavior for a specific profile using composed modules
fn evaluateBehaviorForProfile(composer: *BehaviorComposer, context: BehaviorContext) ComposedBehaviorResult {
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
    const home_tolerance = ProfileConfigs.neutral.return_home.home_tolerance_sq; // This field is actually the tolerance squared
    if (context.distance_from_home * context.distance_from_home > home_tolerance) {
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
    const home_tolerance = ProfileConfigs.friendly.return_home.home_tolerance_sq; // This field is actually the tolerance squared
    if (context.distance_from_home * context.distance_from_home > home_tolerance) {
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

/// Behavior composer storage - hex-specific extension to generic Unit component
/// This allows hex to use the modular system while keeping lib/game generic
const ComposerHashMap = std.HashMap(u32, BehaviorComposer, std.hash_map.AutoContext(u32), std.hash_map.default_max_load_percentage);
var composer_storage: ComposerHashMap = undefined;
var composer_allocator: std.mem.Allocator = undefined;

/// Initialize behavior composer system
pub fn initBehaviorSystem(allocator: std.mem.Allocator) void {
    composer_allocator = allocator;
    composer_storage = ComposerHashMap.init(allocator);
    initEntityIDMapping();
}

/// Cleanup behavior composer system
pub fn deinitBehaviorSystem() void {
    composer_storage.deinit();
    deinitEntityIDMapping();
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

/// Entity ID counter for behavior composer mapping
var next_entity_id: u32 = 1;
var entity_id_map: std.HashMap(usize, u32, std.hash_map.AutoContext(usize), std.hash_map.default_max_load_percentage) = undefined;

/// Initialize entity ID mapping system
fn initEntityIDMapping() void {
    entity_id_map = std.HashMap(usize, u32, std.hash_map.AutoContext(usize), std.hash_map.default_max_load_percentage).init(composer_allocator);
}

/// Cleanup entity ID mapping system
fn deinitEntityIDMapping() void {
    entity_id_map.deinit();
}

/// Get or assign a stable entity ID for a unit pointer
fn getEntityID(unit_ptr: *Unit) u32 {
    const ptr_value = @intFromPtr(unit_ptr);
    
    const result = entity_id_map.getOrPut(ptr_value) catch {
        // Fallback: use a simple hash of the pointer
        return @truncate(std.hash_map.hashString(std.mem.asBytes(&ptr_value)));
    };
    
    if (!result.found_existing) {
        result.value_ptr.* = next_entity_id;
        next_entity_id += 1;
    }
    
    return result.value_ptr.*;
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
    const entity_id = getEntityID(unit_comp);
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
    const context = BehaviorContext.init(
        transform.pos,
        unit_comp.home_pos,
        if (player_alive) player_pos else null,
        player_alive,
        aggro_multiplier,
        dt,
    );
    
    // Evaluate composed behavior
    const result = evaluateBehaviorForProfile(composer, context);
    
    // Apply hex-specific colors based on active behavior
    visual.color = getBehaviorColor(result.active_behavior, profile);
    
    // Apply movement
    transform.vel = result.velocity;
    transform.pos = transform.pos.add(result.velocity.scale(dt));
}

/// Get behavior color for visualization (hex-specific)
/// Maps our new BehaviorType enum to the legacy BehaviorState for backward compatibility
/// with constants.getBehaviorColor() which expects the old enum values
fn getBehaviorColor(behavior: BehaviorType, profile: BehaviorProfile) @import("../lib/core/colors.zig").Color {
    // Map new BehaviorType to legacy BehaviorState for color compatibility with constants.zig
    const legacy_behavior = switch (behavior) {
        .idle => behaviors_mod.behavior_state_machine.BehaviorState.idle,
        .chasing => behaviors_mod.behavior_state_machine.BehaviorState.chasing,
        .fleeing => behaviors_mod.behavior_state_machine.BehaviorState.fleeing,
        .patrolling => behaviors_mod.behavior_state_machine.BehaviorState.patrolling,
        .wandering => behaviors_mod.behavior_state_machine.BehaviorState.idle, // Map wandering to idle
        .returning_home => behaviors_mod.behavior_state_machine.BehaviorState.returning_home,
        .guarding => behaviors_mod.behavior_state_machine.BehaviorState.guarding,
    };
    
    // Use existing constants function
    return constants.getBehaviorColor(legacy_behavior, profile);
}

// All legacy code removed - migration to modular behavior system complete
