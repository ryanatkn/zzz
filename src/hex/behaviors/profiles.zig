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
            0.42, // 0.42m min_distance - get close to player (was 5 pixels)
            12.5, // 12.5m/s chase_speed - fast pursuit (was 150 pixels/s)
            0.0, // chase_duration - no timer needed
            1.15, // lose_range_multiplier - slight tolerance
        );
        pub const return_home = return_home_behavior.ReturnHomeConfig.init(
            1.7, // 1.7m home_tolerance (was 20 pixels)
            8.3, // 8.3m/s return_speed (was 100 pixels/s)
        );
    };

    // Fearful profile: flees early and fast
    pub const fearful = struct {
        pub const flee = flee_behavior.FleeConfig.init(
            constants.UNIT_DETECTION_RADIUS * 1.2, // danger_range - detect early
            16.7, // 16.7m safe_distance - flee far (was 200 pixels)
            16.7, // 16.7m/s flee_speed - very fast escape (was 200 pixels/s)
            0.0, // flee_duration - no timer
        );
        pub const return_home = return_home_behavior.ReturnHomeConfig.init(
            1.25, // 1.25m home_tolerance - tight home area (was 15 pixels)
            10.0, // 10m/s return_speed - quick return (was 120 pixels/s)
        );
    };

    // Neutral profile: ignores player, wanders near home
    pub const neutral = struct {
        pub const wander = wander_behavior.WanderConfig.init(
            6.7, // 6.7m/s wander_speed - leisurely (was 80 pixels/s)
            4.2, // 4.2m wander_radius - close to home (was 50 pixels)
            4.0, // direction_change_interval
        );
        pub const return_home = return_home_behavior.ReturnHomeConfig.init(
            2.1, // 2.1m home_tolerance - moderate area (was 25 pixels)
            8.3, // 8.3m/s return_speed (was 100 pixels/s)
        );
    };

    // Friendly profile: follows player gently
    pub const friendly = struct {
        pub const chase = chase_behavior.ChaseConfig.init(
            constants.UNIT_DETECTION_RADIUS * 0.8, // detection_range - moderate
            1.25, // 1.25m min_distance - don't crowd player (was 15 pixels)
            8.3, // 8.3m/s chase_speed - gentle following (was 100 pixels/s)
            0.0, // chase_duration
            1.2, // lose_range_multiplier - give space
        );
        pub const wander = wander_behavior.WanderConfig.init(
            5.0, // 5m/s wander_speed - slow wandering (was 60 pixels/s)
            6.7, // 6.7m wander_radius - can explore (was 80 pixels)
            5.0, // direction_change_interval - patient
        );
        pub const return_home = return_home_behavior.ReturnHomeConfig.init(
            2.5, // 2.5m home_tolerance - relaxed area (was 30 pixels)
            7.5, // 7.5m/s return_speed (was 90 pixels/s)
        );
    };
};
