// Behavior Composer - State container for unit behaviors based on disposition
// Manages individual behavior states (chase, flee, wander) per unit according to their temperament

const std = @import("std");
const Vec2 = @import("../../lib/math/mod.zig").Vec2;
const behaviors_mod = @import("../../lib/game/behaviors/mod.zig");
const Disposition = @import("../disposition.zig").Disposition;

// Import individual behavior modules
const chase_behavior = behaviors_mod.chase_behavior;
const flee_behavior = behaviors_mod.flee_behavior;
const wander_behavior = behaviors_mod.wander_behavior;

/// Behavior types for tracking active behavior
pub const BehaviorType = enum {
    idle,
    chasing,
    fleeing,
    wandering,
    returning_home,
};

/// Comprehensive behavior state container for modular system
/// Each unit owns a BehaviorComposer that manages individual behavior states
pub const BehaviorComposer = struct {
    // Individual behavior states
    chase_state: chase_behavior.ChaseState,
    flee_state: flee_behavior.FleeState,
    wander_state: wander_behavior.WanderState,
    
    // Unit disposition (temperament that influences behavior selection)
    profile: Disposition,
    current_behavior: BehaviorType,
    
    pub fn init(profile: Disposition, home_pos: Vec2) BehaviorComposer {
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