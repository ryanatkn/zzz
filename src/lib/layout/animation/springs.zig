/// Spring animation system for layout properties
///
/// This module provides physically-based spring animations for smooth layout
/// transitions. Springs are used for position, size, and other layout properties.

const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;

/// Spring configuration parameters
pub const SpringConfig = struct {
    /// Spring stiffness (higher = faster response)
    stiffness: f32 = 300.0,
    /// Spring damping (higher = less oscillation)
    damping: f32 = 30.0,
    /// Mass of the animated object
    mass: f32 = 1.0,
    /// Velocity threshold for considering animation complete
    velocity_threshold: f32 = 0.01,
    /// Position threshold for considering animation complete
    position_threshold: f32 = 0.001,

    /// Get angular frequency (natural frequency)
    pub fn getAngularFrequency(self: SpringConfig) f32 {
        return @sqrt(self.stiffness / self.mass);
    }

    /// Get damping ratio
    pub fn getDampingRatio(self: SpringConfig) f32 {
        return self.damping / (2.0 * @sqrt(self.stiffness * self.mass));
    }

    /// Check if spring is critically damped
    pub fn isCriticallyDamped(self: SpringConfig) bool {
        return @abs(self.getDampingRatio() - 1.0) < 0.01;
    }

    /// Check if spring is overdamped
    pub fn isOverdamped(self: SpringConfig) bool {
        return self.getDampingRatio() > 1.0;
    }

    /// Check if spring is underdamped
    pub fn isUnderdamped(self: SpringConfig) bool {
        return self.getDampingRatio() < 1.0;
    }
};

/// 1D spring for animating scalar values
pub const Spring1D = struct {
    current: f32,
    target: f32,
    velocity: f32,
    config: SpringConfig,

    pub fn init(initial_value: f32, config: SpringConfig) Spring1D {
        return Spring1D{
            .current = initial_value,
            .target = initial_value,
            .velocity = 0.0,
            .config = config,
        };
    }

    /// Set new target value
    pub fn setTarget(self: *Spring1D, target: f32) void {
        self.target = target;
    }

    /// Update spring physics
    pub fn update(self: *Spring1D, delta_time: f32) void {
        const displacement = self.current - self.target;
        const spring_force = -self.config.stiffness * displacement;
        const damping_force = -self.config.damping * self.velocity;
        
        const acceleration = (spring_force + damping_force) / self.config.mass;
        
        self.velocity += acceleration * delta_time;
        self.current += self.velocity * delta_time;
    }

    /// Check if animation is complete
    pub fn isAtRest(self: *const Spring1D) bool {
        const displacement = @abs(self.current - self.target);
        const velocity = @abs(self.velocity);
        
        return displacement < self.config.position_threshold and 
               velocity < self.config.velocity_threshold;
    }

    /// Snap to target (stops animation)
    pub fn snapToTarget(self: *Spring1D) void {
        self.current = self.target;
        self.velocity = 0.0;
    }
};

/// 2D spring for animating Vec2 values
pub const Spring2D = struct {
    current: Vec2,
    target: Vec2,
    velocity: Vec2,
    config: SpringConfig,

    pub fn init(initial_value: Vec2, config: SpringConfig) Spring2D {
        return Spring2D{
            .current = initial_value,
            .target = initial_value,
            .velocity = Vec2.ZERO,
            .config = config,
        };
    }

    /// Set new target value
    pub fn setTarget(self: *Spring2D, target: Vec2) void {
        self.target = target;
    }

    /// Update spring physics
    pub fn update(self: *Spring2D, delta_time: f32) void {
        const displacement = self.current.subtract(self.target);
        const spring_force = displacement.scale(-self.config.stiffness);
        const damping_force = self.velocity.scale(-self.config.damping);
        
        const acceleration = spring_force.add(damping_force).scale(1.0 / self.config.mass);
        
        self.velocity = self.velocity.add(acceleration.scale(delta_time));
        self.current = self.current.add(self.velocity.scale(delta_time));
    }

    /// Check if animation is complete
    pub fn isAtRest(self: *const Spring2D) bool {
        const displacement = self.current.subtract(self.target).length();
        const velocity = self.velocity.length();
        
        return displacement < self.config.position_threshold and 
               velocity < self.config.velocity_threshold;
    }

    /// Snap to target (stops animation)
    pub fn snapToTarget(self: *Spring2D) void {
        self.current = self.target;
        self.velocity = Vec2.ZERO;
    }
};

/// Layout-specific spring for animating layout properties
pub const LayoutSpring = struct {
    position: Spring2D,
    size: Spring2D,
    opacity: Spring1D,
    rotation: Spring1D,
    scale: Spring1D,

    pub fn init(initial_position: Vec2, initial_size: Vec2, config: SpringConfig) LayoutSpring {
        return LayoutSpring{
            .position = Spring2D.init(initial_position, config),
            .size = Spring2D.init(initial_size, config),
            .opacity = Spring1D.init(1.0, config),
            .rotation = Spring1D.init(0.0, config),
            .scale = Spring1D.init(1.0, config),
        };
    }

    /// Update all spring components
    pub fn update(self: *LayoutSpring, delta_time: f32) void {
        self.position.update(delta_time);
        self.size.update(delta_time);
        self.opacity.update(delta_time);
        self.rotation.update(delta_time);
        self.scale.update(delta_time);
    }

    /// Check if all animations are complete
    pub fn isAtRest(self: *const LayoutSpring) bool {
        return self.position.isAtRest() and
               self.size.isAtRest() and
               self.opacity.isAtRest() and
               self.rotation.isAtRest() and
               self.scale.isAtRest();
    }

    /// Set target layout state
    pub fn setTarget(self: *LayoutSpring, position: Vec2, size: Vec2) void {
        self.position.setTarget(position);
        self.size.setTarget(size);
    }

    /// Set target opacity
    pub fn setTargetOpacity(self: *LayoutSpring, opacity: f32) void {
        self.opacity.setTarget(std.math.clamp(opacity, 0.0, 1.0));
    }

    /// Set target rotation (in radians)
    pub fn setTargetRotation(self: *LayoutSpring, rotation: f32) void {
        self.rotation.setTarget(rotation);
    }

    /// Set target scale
    pub fn setTargetScale(self: *LayoutSpring, scale: f32) void {
        self.scale.setTarget(scale);
    }

    /// Get current layout state
    pub fn getCurrentState(self: *const LayoutSpring) LayoutState {
        return LayoutState{
            .position = self.position.current,
            .size = self.size.current,
            .opacity = self.opacity.current,
            .rotation = self.rotation.current,
            .scale = self.scale.current,
        };
    }
};

/// Current state of animated layout properties
pub const LayoutState = struct {
    position: Vec2,
    size: Vec2,
    opacity: f32,
    rotation: f32,
    scale: f32,
};

/// Preset spring configurations for different animation feels
pub const SpringPresets = struct {
    /// Gentle spring (slow, smooth)
    pub const gentle = SpringConfig{
        .stiffness = 120.0,
        .damping = 14.0,
        .mass = 1.0,
    };

    /// Wobbly spring (bouncy)
    pub const wobbly = SpringConfig{
        .stiffness = 180.0,
        .damping = 12.0,
        .mass = 1.0,
    };

    /// Stiff spring (fast, minimal overshoot)
    pub const stiff = SpringConfig{
        .stiffness = 400.0,
        .damping = 40.0,
        .mass = 1.0,
    };

    /// Slow spring (very gradual)
    pub const slow = SpringConfig{
        .stiffness = 280.0,
        .damping = 60.0,
        .mass = 3.0,
    };

    /// Molasses spring (extremely slow)
    pub const molasses = SpringConfig{
        .stiffness = 280.0,
        .damping = 120.0,
        .mass = 3.0,
    };
};

// Tests
test "spring 1D basic animation" {
    const testing = std.testing;
    
    var spring = Spring1D.init(0.0, SpringPresets.stiff);
    spring.setTarget(100.0);
    
    // Should not be at rest initially
    try testing.expect(!spring.isAtRest());
    
    // Animate for several frames
    for (0..60) |_| {
        spring.update(1.0 / 60.0); // 60 FPS
    }
    
    // Should be close to target
    try testing.expect(@abs(spring.current - 100.0) < 1.0);
}

test "spring 2D vector animation" {
    const testing = std.testing;
    
    const start = Vec2{ .x = 0.0, .y = 0.0 };
    const target = Vec2{ .x = 100.0, .y = 50.0 };
    
    var spring = Spring2D.init(start, SpringPresets.stiff);
    spring.setTarget(target);
    
    // Should not be at rest initially
    try testing.expect(!spring.isAtRest());
    
    // Animate for several frames
    for (0..60) |_| {
        spring.update(1.0 / 60.0);
    }
    
    // Should be close to target
    const distance = spring.current.subtract(target).length();
    try testing.expect(distance < 2.0);
}

test "layout spring comprehensive animation" {
    const testing = std.testing;
    
    const initial_pos = Vec2{ .x = 10.0, .y = 20.0 };
    const initial_size = Vec2{ .x = 100.0, .y = 50.0 };
    
    var layout_spring = LayoutSpring.init(initial_pos, initial_size, SpringPresets.gentle);
    
    // Set new targets
    layout_spring.setTarget(Vec2{ .x = 50.0, .y = 100.0 }, Vec2{ .x = 200.0, .y = 150.0 });
    layout_spring.setTargetOpacity(0.5);
    layout_spring.setTargetRotation(std.math.pi / 4.0);
    layout_spring.setTargetScale(1.5);
    
    // Should not be at rest initially
    try testing.expect(!layout_spring.isAtRest());
    
    // Animate for several frames
    for (0..120) |_| {
        layout_spring.update(1.0 / 60.0);
    }
    
    const state = layout_spring.getCurrentState();
    
    // Check that values are close to targets
    try testing.expect(@abs(state.position.x - 50.0) < 2.0);
    try testing.expect(@abs(state.position.y - 100.0) < 2.0);
    try testing.expect(@abs(state.size.x - 200.0) < 5.0);
    try testing.expect(@abs(state.size.y - 150.0) < 5.0);
    try testing.expect(@abs(state.opacity - 0.5) < 0.05);
    try testing.expect(@abs(state.scale - 1.5) < 0.05);
}

test "spring damping characteristics" {
    const testing = std.testing;
    
    // Test critically damped spring
    const critical_config = SpringConfig{
        .stiffness = 100.0,
        .damping = 20.0, // 2 * sqrt(100 * 1) = 20
        .mass = 1.0,
    };
    try testing.expect(critical_config.isCriticallyDamped());
    
    // Test overdamped spring
    const overdamped_config = SpringConfig{
        .stiffness = 100.0,
        .damping = 30.0, // > 20
        .mass = 1.0,
    };
    try testing.expect(overdamped_config.isOverdamped());
    
    // Test underdamped spring
    const underdamped_config = SpringConfig{
        .stiffness = 100.0,
        .damping = 10.0, // < 20
        .mass = 1.0,
    };
    try testing.expect(underdamped_config.isUnderdamped());
}