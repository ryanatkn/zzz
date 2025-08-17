/// Engine-level constants for the game engine
/// These are reusable across different games and don't depend on game-specific logic

// ========================
// SCREEN & DISPLAY
// ========================

/// Base screen dimensions - foundation for UI coordinate system
pub const SCREEN = struct {
    pub const BASE_WIDTH: f32 = 1920.0;
    pub const BASE_HEIGHT: f32 = 1080.0;
    pub const ASPECT_RATIO: f32 = 16.0 / 9.0;

    /// Calculate center coordinates
    pub fn centerX(width: f32) f32 {
        return width / 2.0;
    }

    pub fn centerY(height: f32) f32 {
        return height / 2.0;
    }

    /// Scale coordinate from base resolution to target resolution
    pub fn scaleFromBase(coord: f32, is_x: bool, target_width: f32, target_height: f32) f32 {
        if (is_x) {
            return coord * (target_width / BASE_WIDTH);
        } else {
            return coord * (target_height / BASE_HEIGHT);
        }
    }
};

// ========================
// RENDERING LIMITS
// ========================

/// Maximum rendering limits for performance
pub const RENDERING = struct {
    pub const MAX_BORDER_LAYERS: usize = 8;
    pub const VISIBILITY_THRESHOLD: f32 = 0.5; // Minimum width for visibility
    pub const MAX_EFFECTS: usize = 256; // Maximum simultaneous effects
    pub const MAX_PARTICLES: usize = 1024; // Maximum particles
};

// ========================
// PHYSICS CONSTANTS
// ========================

/// Physics simulation constants
pub const PHYSICS = struct {
    pub const DEFAULT_GRAVITY: f32 = 9.81;
    pub const DEFAULT_FRICTION: f32 = 0.8;
    pub const COLLISION_EPSILON: f32 = 0.001; // Minimum distance for collision resolution
    pub const MAX_VELOCITY: f32 = 2000.0; // Maximum velocity to prevent tunneling
};

// ========================
// UI CONSTANTS
// ========================

/// User interface constants
pub const UI = struct {
    pub const DEFAULT_MARGIN: f32 = 10.0;
    pub const DEFAULT_PADDING: f32 = 5.0;
    pub const DEFAULT_FONT_SIZE: f32 = 16.0;
    pub const LARGE_FONT_SIZE: f32 = 24.0;
    pub const SMALL_FONT_SIZE: f32 = 12.0;

    // Text rendering
    pub const TEXT_PIXEL_SIZE: f32 = 1.5;
    pub const DIGIT_SPACING: f32 = 12.0;

    // HUD positioning
    pub const HUD_MARGIN_X: f32 = 100.0;
    pub const HUD_MARGIN_Y: f32 = 100.0;
    pub const FALLBACK_POSITION_X: f32 = 1840.0;
    pub const FALLBACK_POSITION_Y: f32 = 1060.0;
};

// ========================
// PERFORMANCE LIMITS
// ========================

/// Performance-related constants and limits
pub const PERFORMANCE = struct {
    pub const TARGET_FPS: u32 = 60;
    pub const MAX_FRAME_TIME: f32 = 1.0 / 30.0; // Cap at 30 FPS minimum
    pub const POOL_DEFAULT_SIZE: usize = 32;
    pub const POOL_MAX_SIZE: usize = 1024;
    pub const CACHE_SIZE: usize = 256;

    // Update frequency limits
    pub const MAX_UPDATES_PER_FRAME: u32 = 10;
    pub const FIXED_TIMESTEP: f32 = 1.0 / 60.0; // 60 Hz physics
};

// ========================
// ANIMATION CONSTANTS
// ========================

/// Animation and interpolation constants
pub const ANIMATION = struct {
    pub const DEFAULT_DURATION: f32 = 1.0; // 1 second
    pub const PULSE_FREQUENCY: f32 = 2.0; // 2 Hz
    pub const COLOR_CYCLE_FREQUENCY: f32 = 4.0; // 4 Hz
    pub const BOUNCE_STRENGTH: f32 = 0.1;

    // Easing constants
    pub const EASE_IN_FACTOR: f32 = 2.0;
    pub const EASE_OUT_FACTOR: f32 = 2.0;
    pub const SMOOTHNESS: f32 = 0.5;
};

// ========================
// CAMERA CONSTANTS
// ========================

/// Camera and viewport constants
pub const CAMERA = struct {
    pub const DEFAULT_ZOOM: f32 = 1.0;
    pub const MIN_ZOOM: f32 = 0.1;
    pub const MAX_ZOOM: f32 = 10.0;
    pub const ZOOM_FACTOR: f32 = 1.1; // 10% per zoom step
    pub const FOLLOW_SMOOTHNESS: f32 = 0.1;
    pub const BOUNDARY_MARGIN: f32 = 10.0;
};

// ========================
// INPUT CONSTANTS
// ========================

/// Input handling constants
pub const INPUT = struct {
    pub const DOUBLE_CLICK_TIME: f32 = 0.3; // 300ms
    pub const HOLD_TIME: f32 = 0.5; // 500ms
    pub const REPEAT_DELAY: f32 = 0.5; // 500ms initial delay
    pub const REPEAT_RATE: f32 = 0.1; // 100ms repeat rate
    pub const DEADZONE: f32 = 0.2; // Controller deadzone
};

// ========================
// TIMING CONSTANTS
// ========================

/// Timing and cooldown constants
pub const TIMING = struct {
    pub const DEFAULT_COOLDOWN: f32 = 1.0; // 1 second
    pub const MIN_COOLDOWN: f32 = 0.1; // 100ms
    pub const MAX_COOLDOWN: f32 = 60.0; // 1 minute
    pub const FRAME_TIME_HISTORY: usize = 60; // Frames to average
    pub const TIMER_PRECISION: f32 = 0.001; // 1ms precision
};

// ========================
// UTILITY FUNCTIONS
// ========================

/// Utility functions for engine constants
pub const Utils = struct {
    /// Convert seconds to frames at target FPS
    pub fn secondsToFrames(seconds: f32) u32 {
        return @intFromFloat(seconds * @as(f32, @floatFromInt(PERFORMANCE.TARGET_FPS)));
    }

    /// Convert frames to seconds at target FPS
    pub fn framesToSeconds(frames: u32) f32 {
        return @as(f32, @floatFromInt(frames)) / @as(f32, @floatFromInt(PERFORMANCE.TARGET_FPS));
    }

    /// Check if value is within epsilon of target
    pub fn nearlyEqual(a: f32, b: f32, epsilon: f32) bool {
        return @abs(a - b) < epsilon;
    }

    /// Safe division that returns 0 if denominator is near zero
    pub fn safeDivide(numerator: f32, denominator: f32) f32 {
        return if (nearlyEqual(denominator, 0.0, PHYSICS.COLLISION_EPSILON)) 0.0 else numerator / denominator;
    }
};

// ========================
// COMPILE-TIME VALIDATION
// ========================

comptime {
    // Validate screen dimensions
    if (SCREEN.BASE_WIDTH <= 0 or SCREEN.BASE_HEIGHT <= 0) {
        @compileError("Screen dimensions must be positive");
    }

    // Validate aspect ratio
    if (@abs(SCREEN.ASPECT_RATIO - (SCREEN.BASE_WIDTH / SCREEN.BASE_HEIGHT)) > 0.01) {
        @compileError("Aspect ratio doesn't match screen dimensions");
    }

    // Validate zoom ranges
    if (CAMERA.MIN_ZOOM >= CAMERA.MAX_ZOOM) {
        @compileError("Invalid zoom range");
    }

    // Validate performance limits
    if (PERFORMANCE.TARGET_FPS == 0) {
        @compileError("Target FPS must be positive");
    }
}

// ========================
// TESTS
// ========================

const std = @import("std");

test "screen utilities" {
    // Test center calculations
    try std.testing.expectApproxEqAbs(@as(f32, 960.0), SCREEN.centerX(1920.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 540.0), SCREEN.centerY(1080.0), 0.001);

    // Test scaling
    const scaled = SCREEN.scaleFromBase(100.0, true, 960.0, 540.0);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), scaled, 0.001);
}

test "timing utilities" {
    // Test frame conversions
    const frames = Utils.secondsToFrames(1.0);
    try std.testing.expect(frames == PERFORMANCE.TARGET_FPS);

    const seconds = Utils.framesToSeconds(PERFORMANCE.TARGET_FPS);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), seconds, 0.001);
}

test "utility functions" {
    // Test nearly equal
    try std.testing.expect(Utils.nearlyEqual(1.0, 1.0001, 0.001));
    try std.testing.expect(!Utils.nearlyEqual(1.0, 1.1, 0.001));

    // Test safe divide
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), Utils.safeDivide(10.0, 2.0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), Utils.safeDivide(10.0, 0.0), 0.001);
}
