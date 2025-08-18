// Disposition Profiles - Configuration constants for 4 disposition types
// Defines chase, flee, wander, and return_home configs per disposition

const constants = @import("../constants.zig");
const behaviors_mod = @import("../../lib/game/behaviors/mod.zig");

// Import individual behavior modules for configuration
const chase_behavior = behaviors_mod.chase_behavior;
const flee_behavior = behaviors_mod.flee_behavior;
const wander_behavior = behaviors_mod.wander_behavior;
const return_home_behavior = behaviors_mod.return_home_behavior;

/// Disposition-specific behavior configurations
/// Each disposition defines which behaviors it uses and their parameters
pub const ProfileConfigs = struct {
    // Hostile profile: aggressive chaser
    pub const hostile = struct {
        pub const chase = chase_behavior.ChaseConfig.init(
            constants.UNIT_DETECTION_RADIUS, // detection_range
            5.0, // min_distance - get close to player
            150.0, // chase_speed - fast pursuit
            0.0, // chase_duration - no timer needed
            1.15, // lose_range_multiplier - slight tolerance
        );
        pub const return_home = return_home_behavior.ReturnHomeConfig.init(
            20.0, // home_tolerance
            100.0, // return_speed
        );
    };
    
    // Fearful profile: flees early and fast
    pub const fearful = struct {
        pub const flee = flee_behavior.FleeConfig.init(
            constants.UNIT_DETECTION_RADIUS * 1.2, // danger_range - detect early
            200.0, // safe_distance - flee far
            200.0, // flee_speed - very fast escape
            0.0, // flee_duration - no timer
        );
        pub const return_home = return_home_behavior.ReturnHomeConfig.init(
            15.0, // home_tolerance - tight home area
            120.0, // return_speed - quick return
        );
    };
    
    // Neutral profile: ignores player, wanders near home
    pub const neutral = struct {
        pub const wander = wander_behavior.WanderConfig.init(
            80.0, // wander_speed - leisurely
            50.0, // wander_radius - close to home
            4.0, // direction_change_interval
        );
        pub const return_home = return_home_behavior.ReturnHomeConfig.init(
            25.0, // home_tolerance - moderate area
            100.0, // return_speed
        );
    };
    
    // Friendly profile: follows player gently
    pub const friendly = struct {
        pub const chase = chase_behavior.ChaseConfig.init(
            constants.UNIT_DETECTION_RADIUS * 0.8, // detection_range - moderate
            15.0, // min_distance - don't crowd player
            100.0, // chase_speed - gentle following
            0.0, // chase_duration
            1.2, // lose_range_multiplier - give space
        );
        pub const wander = wander_behavior.WanderConfig.init(
            60.0, // wander_speed - slow wandering
            80.0, // wander_radius - can explore
            5.0, // direction_change_interval - patient
        );
        pub const return_home = return_home_behavior.ReturnHomeConfig.init(
            30.0, // home_tolerance - relaxed area
            90.0, // return_speed
        );
    };
};