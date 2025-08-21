/// Layout transition system for smooth property changes
///
/// This module provides declarative transitions for layout properties,
/// supporting various easing functions and transition orchestration.
const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../core/types.zig");
const springs = @import("springs.zig");

const Vec2 = math.Vec2;

/// Easing function types
pub const EasingFunction = enum {
    linear,
    ease_in_quad,
    ease_out_quad,
    ease_in_out_quad,
    ease_in_cubic,
    ease_out_cubic,
    ease_in_out_cubic,
    ease_in_quart,
    ease_out_quart,
    ease_in_out_quart,
    ease_in_sine,
    ease_out_sine,
    ease_in_out_sine,
    ease_in_expo,
    ease_out_expo,
    ease_in_out_expo,
    ease_in_circ,
    ease_out_circ,
    ease_in_out_circ,
    ease_in_back,
    ease_out_back,
    ease_in_out_back,
    ease_in_elastic,
    ease_out_elastic,
    ease_in_out_elastic,
    ease_in_bounce,
    ease_out_bounce,
    ease_in_out_bounce,

    /// Apply easing function to normalized time (0.0 to 1.0)
    pub fn apply(self: EasingFunction, t: f32) f32 {
        const clamped_t = std.math.clamp(t, 0.0, 1.0);

        return switch (self) {
            .linear => clamped_t,
            .ease_in_quad => clamped_t * clamped_t,
            .ease_out_quad => 1.0 - (1.0 - clamped_t) * (1.0 - clamped_t),
            .ease_in_out_quad => if (clamped_t < 0.5)
                2.0 * clamped_t * clamped_t
            else
                1.0 - std.math.pow(f32, -2.0 * clamped_t + 2.0, 2.0) / 2.0,
            .ease_in_cubic => clamped_t * clamped_t * clamped_t,
            .ease_out_cubic => 1.0 - std.math.pow(f32, 1.0 - clamped_t, 3.0),
            .ease_in_out_cubic => if (clamped_t < 0.5)
                4.0 * clamped_t * clamped_t * clamped_t
            else
                1.0 - std.math.pow(f32, -2.0 * clamped_t + 2.0, 3.0) / 2.0,
            .ease_in_sine => 1.0 - @cos((clamped_t * std.math.pi) / 2.0),
            .ease_out_sine => @sin((clamped_t * std.math.pi) / 2.0),
            .ease_in_out_sine => -(@cos(std.math.pi * clamped_t) - 1.0) / 2.0,
            // TODO: Implement remaining easing functions
            else => clamped_t,
        };
    }
};

/// Transition timing configuration
pub const TimingConfig = struct {
    /// Duration in seconds
    duration: f32,
    /// Delay before starting in seconds
    delay: f32 = 0.0,
    /// Easing function to use
    easing: EasingFunction = .ease_in_out_quad,
    /// Whether to repeat the transition
    repeat: bool = false,
    /// Whether to alternate direction on repeat
    alternate: bool = false,

    pub fn getTotalDuration(self: TimingConfig) f32 {
        return self.delay + self.duration;
    }
};

/// Transition state
pub const TransitionState = enum {
    idle,
    delayed,
    running,
    completed,
    cancelled,
};

/// Generic transition for any property type
pub fn Transition(comptime T: type) type {
    return struct {
        start_value: T,
        end_value: T,
        current_value: T,
        timing: TimingConfig,
        state: TransitionState,
        elapsed_time: f32,

        const Self = @This();

        pub fn init(start_value: T, end_value: T, timing: TimingConfig) Self {
            return Self{
                .start_value = start_value,
                .end_value = end_value,
                .current_value = start_value,
                .timing = timing,
                .state = .idle,
                .elapsed_time = 0.0,
            };
        }

        /// Start the transition
        pub fn start(self: *Self) void {
            self.state = if (self.timing.delay > 0.0) .delayed else .running;
            self.elapsed_time = 0.0;
        }

        /// Update transition
        pub fn update(self: *Self, delta_time: f32) void {
            if (self.state == .idle or self.state == .completed or self.state == .cancelled) {
                return;
            }

            self.elapsed_time += delta_time;

            switch (self.state) {
                .delayed => {
                    if (self.elapsed_time >= self.timing.delay) {
                        self.state = .running;
                    }
                },
                .running => {
                    const animation_time = self.elapsed_time - self.timing.delay;
                    if (animation_time >= self.timing.duration) {
                        if (self.timing.repeat) {
                            self.elapsed_time = 0.0;
                            if (self.timing.alternate) {
                                const temp = self.start_value;
                                self.start_value = self.end_value;
                                self.end_value = temp;
                            }
                        } else {
                            self.state = .completed;
                            self.current_value = self.end_value;
                            return;
                        }
                    }

                    const progress = self.timing.easing.apply(animation_time / self.timing.duration);
                    self.current_value = self.interpolate(self.start_value, self.end_value, progress);
                },
                else => {},
            }
        }

        /// Cancel the transition
        pub fn cancel(self: *Self) void {
            self.state = .cancelled;
        }

        /// Check if transition is complete
        pub fn isComplete(self: *const Self) bool {
            return self.state == .completed;
        }

        /// Check if transition is running
        pub fn isRunning(self: *const Self) bool {
            return self.state == .running or self.state == .delayed;
        }

        /// Set new end value (restarts transition)
        pub fn setTarget(self: *Self, target: T) void {
            self.start_value = self.current_value;
            self.end_value = target;
            self.start();
        }

        /// Interpolate between two values
        fn interpolate(self: *Self, start_value: T, end_value: T, t: f32) T {
            _ = self;

            // Type-specific interpolation
            return switch (@typeInfo(T)) {
                .Float => start_value + (end_value - start_value) * t,
                .Int => @intFromFloat(@as(f64, @floatFromInt(start_value)) + (@as(f64, @floatFromInt(end_value)) - @as(f64, @floatFromInt(start_value))) * @as(f64, t)),
                .Struct => {
                    // Handle Vec2 and similar structures
                    if (@hasField(T, "x") and @hasField(T, "y")) {
                        return T{
                            .x = start_value.x + (end_value.x - start_value.x) * t,
                            .y = start_value.y + (end_value.y - start_value.y) * t,
                        };
                    }
                    // TODO: Handle other struct types
                    @compileError("Unsupported type for transition interpolation: " ++ @typeName(T));
                },
                else => @compileError("Unsupported type for transition interpolation: " ++ @typeName(T)),
            };
        }
    };
}

/// Common transition types
pub const FloatTransition = Transition(f32);
pub const Vec2Transition = Transition(Vec2);
pub const IntTransition = Transition(i32);

/// Layout property transition orchestrator
pub const LayoutTransition = struct {
    position: Vec2Transition,
    size: Vec2Transition,
    opacity: FloatTransition,
    rotation: FloatTransition,
    scale: FloatTransition,

    pub fn init(
        initial_position: Vec2,
        initial_size: Vec2,
        timing: TimingConfig,
    ) LayoutTransition {
        return LayoutTransition{
            .position = Vec2Transition.init(initial_position, initial_position, timing),
            .size = Vec2Transition.init(initial_size, initial_size, timing),
            .opacity = FloatTransition.init(1.0, 1.0, timing),
            .rotation = FloatTransition.init(0.0, 0.0, timing),
            .scale = FloatTransition.init(1.0, 1.0, timing),
        };
    }

    /// Update all transitions
    pub fn update(self: *LayoutTransition, delta_time: f32) void {
        self.position.update(delta_time);
        self.size.update(delta_time);
        self.opacity.update(delta_time);
        self.rotation.update(delta_time);
        self.scale.update(delta_time);
    }

    /// Set target layout state
    pub fn setTarget(self: *LayoutTransition, position: Vec2, size: Vec2) void {
        self.position.setTarget(position);
        self.size.setTarget(size);
    }

    /// Set target opacity
    pub fn setTargetOpacity(self: *LayoutTransition, opacity: f32) void {
        self.opacity.setTarget(std.math.clamp(opacity, 0.0, 1.0));
    }

    /// Set target rotation
    pub fn setTargetRotation(self: *LayoutTransition, rotation: f32) void {
        self.rotation.setTarget(rotation);
    }

    /// Set target scale
    pub fn setTargetScale(self: *LayoutTransition, scale: f32) void {
        self.scale.setTarget(scale);
    }

    /// Get current state
    pub fn getCurrentState(self: *const LayoutTransition) springs.LayoutState {
        return springs.LayoutState{
            .position = self.position.current_value,
            .size = self.size.current_value,
            .opacity = self.opacity.current_value,
            .rotation = self.rotation.current_value,
            .scale = self.scale.current_value,
        };
    }

    /// Check if all transitions are complete
    pub fn isComplete(self: *const LayoutTransition) bool {
        return self.position.isComplete() and
            self.size.isComplete() and
            self.opacity.isComplete() and
            self.rotation.isComplete() and
            self.scale.isComplete();
    }

    /// Start all transitions
    pub fn start(self: *LayoutTransition) void {
        self.position.start();
        self.size.start();
        self.opacity.start();
        self.rotation.start();
        self.scale.start();
    }

    /// Cancel all transitions
    pub fn cancel(self: *LayoutTransition) void {
        self.position.cancel();
        self.size.cancel();
        self.opacity.cancel();
        self.rotation.cancel();
        self.scale.cancel();
    }
};

/// Transition group for coordinating multiple element transitions
pub const TransitionGroup = struct {
    allocator: std.mem.Allocator,
    transitions: std.ArrayList(*LayoutTransition),
    stagger_delay: f32,

    pub fn init(allocator: std.mem.Allocator, stagger_delay: f32) TransitionGroup {
        return TransitionGroup{
            .allocator = allocator,
            .transitions = std.ArrayList(*LayoutTransition).init(allocator),
            .stagger_delay = stagger_delay,
        };
    }

    pub fn deinit(self: *TransitionGroup) void {
        self.transitions.deinit();
    }

    /// Add transition to group
    pub fn addTransition(self: *TransitionGroup, transition: *LayoutTransition) !void {
        try self.transitions.append(transition);

        // Apply stagger delay
        const index = self.transitions.items.len - 1;
        const stagger = @as(f32, @floatFromInt(index)) * self.stagger_delay;

        transition.position.timing.delay += stagger;
        transition.size.timing.delay += stagger;
        transition.opacity.timing.delay += stagger;
        transition.rotation.timing.delay += stagger;
        transition.scale.timing.delay += stagger;
    }

    /// Start all transitions in group
    pub fn start(self: *TransitionGroup) void {
        for (self.transitions.items) |transition| {
            transition.start();
        }
    }

    /// Update all transitions in group
    pub fn update(self: *TransitionGroup, delta_time: f32) void {
        for (self.transitions.items) |transition| {
            transition.update(delta_time);
        }
    }

    /// Check if all transitions are complete
    pub fn isComplete(self: *const TransitionGroup) bool {
        for (self.transitions.items) |transition| {
            if (!transition.isComplete()) {
                return false;
            }
        }
        return true;
    }

    /// Cancel all transitions
    pub fn cancel(self: *TransitionGroup) void {
        for (self.transitions.items) |transition| {
            transition.cancel();
        }
    }
};

/// Preset timing configurations
pub const TimingPresets = struct {
    /// Quick transition (0.15s)
    pub const quick = TimingConfig{
        .duration = 0.15,
        .easing = .ease_out_quad,
    };

    /// Standard transition (0.3s)
    pub const standard = TimingConfig{
        .duration = 0.3,
        .easing = .ease_in_out_quad,
    };

    /// Slow transition (0.5s)
    pub const slow = TimingConfig{
        .duration = 0.5,
        .easing = .ease_in_out_cubic,
    };

    /// Entering transition
    pub const enter = TimingConfig{
        .duration = 0.225,
        .easing = .ease_out_cubic,
    };

    /// Exiting transition
    pub const exit = TimingConfig{
        .duration = 0.195,
        .easing = .ease_in_cubic,
    };
};

// Tests
test "float transition basic animation" {
    const testing = std.testing;

    var transition = FloatTransition.init(0.0, 100.0, TimingPresets.quick);
    transition.start();

    // Should be running
    try testing.expect(transition.isRunning());

    // Update halfway through
    transition.update(TimingPresets.quick.duration / 2.0);
    try testing.expect(@abs(transition.current_value - 50.0) < 5.0); // Approximate halfway

    // Complete the transition
    transition.update(TimingPresets.quick.duration);
    try testing.expect(transition.isComplete());
    try testing.expect(transition.current_value == 100.0);
}

test "vec2 transition with easing" {
    const testing = std.testing;

    const start = Vec2{ .x = 0.0, .y = 0.0 };
    const end = Vec2{ .x = 100.0, .y = 50.0 };

    var transition = Vec2Transition.init(start, end, TimingConfig{
        .duration = 1.0,
        .easing = .linear,
    });
    transition.start();

    // Update to 25% progress
    transition.update(0.25);
    try testing.expect(@abs(transition.current_value.x - 25.0) < 0.1);
    try testing.expect(@abs(transition.current_value.y - 12.5) < 0.1);

    // Update to completion
    transition.update(0.75);
    try testing.expect(transition.isComplete());
    try testing.expect(transition.current_value.x == 100.0);
    try testing.expect(transition.current_value.y == 50.0);
}

test "layout transition orchestration" {
    const testing = std.testing;

    const initial_pos = Vec2{ .x = 10.0, .y = 20.0 };
    const initial_size = Vec2{ .x = 100.0, .y = 50.0 };

    var layout_transition = LayoutTransition.init(initial_pos, initial_size, TimingPresets.standard);

    // Set targets
    layout_transition.setTarget(Vec2{ .x = 50.0, .y = 100.0 }, Vec2{ .x = 200.0, .y = 150.0 });
    layout_transition.setTargetOpacity(0.5);

    layout_transition.start();
    try testing.expect(!layout_transition.isComplete());

    // Animate to completion
    layout_transition.update(TimingPresets.standard.duration);

    const state = layout_transition.getCurrentState();
    try testing.expect(state.position.x == 50.0);
    try testing.expect(state.position.y == 100.0);
    try testing.expect(state.opacity == 0.5);
}

test "easing function behavior" {
    const testing = std.testing;

    // Linear should be exactly proportional
    try testing.expect(EasingFunction.linear.apply(0.5) == 0.5);

    // Ease in quad should be slower at the start
    const ease_in_half = EasingFunction.ease_in_quad.apply(0.5);
    try testing.expect(ease_in_half < 0.5);
    try testing.expect(ease_in_half == 0.25); // 0.5^2

    // Ease out quad should be faster at the start
    const ease_out_half = EasingFunction.ease_out_quad.apply(0.5);
    try testing.expect(ease_out_half > 0.5);

    // All functions should return 0 at t=0 and 1 at t=1
    const functions = [_]EasingFunction{ .linear, .ease_in_quad, .ease_out_quad, .ease_in_out_quad };
    for (functions) |func| {
        try testing.expect(func.apply(0.0) == 0.0);
        try testing.expect(func.apply(1.0) == 1.0);
    }
}
