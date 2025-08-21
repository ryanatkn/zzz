/// Animation sequencer for coordinating complex layout animations
///
/// This module provides tools for creating sequences, groups, and timelines
/// of layout animations with precise timing control.
const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");
const springs = @import("springs.zig");
const transitions = @import("transitions.zig");

const Vec2 = math.Vec2;

/// Animation step in a sequence
pub const AnimationStep = struct {
    /// When this step should start (in seconds from sequence start)
    start_time: f32,
    /// Duration of this step (in seconds)
    duration: f32,
    /// Animation type for this step
    animation_type: AnimationType,
    /// Target values for this step
    target: AnimationTarget,
    /// Easing function to use
    easing: transitions.EasingFunction = .ease_in_out_quad,

    pub const AnimationType = enum {
        position,
        size,
        opacity,
        rotation,
        scale,
        layout, // Combined position and size
        fade_in,
        fade_out,
        slide_in_left,
        slide_in_right,
        slide_in_up,
        slide_in_down,
        slide_out_left,
        slide_out_right,
        slide_out_up,
        slide_out_down,
        scale_in,
        scale_out,
        bounce_in,
        bounce_out,
    };

    pub const AnimationTarget = union(AnimationType) {
        position: Vec2,
        size: Vec2,
        opacity: f32,
        rotation: f32,
        scale: f32,
        layout: struct { position: Vec2, size: Vec2 },
        fade_in: f32, // Target opacity
        fade_out: f32, // Target opacity
        slide_in_left: f32, // Distance to slide
        slide_in_right: f32,
        slide_in_up: f32,
        slide_in_down: f32,
        slide_out_left: f32,
        slide_out_right: f32,
        slide_out_up: f32,
        slide_out_down: f32,
        scale_in: f32, // Target scale
        scale_out: f32,
        bounce_in: void,
        bounce_out: void,
    };

    pub fn getEndTime(self: AnimationStep) f32 {
        return self.start_time + self.duration;
    }
};

/// Animation sequence for a single element
pub const AnimationSequence = struct {
    allocator: std.mem.Allocator,
    steps: std.ArrayList(AnimationStep),
    current_step: ?usize,
    sequence_time: f32,
    is_playing: bool,
    is_looping: bool,

    // Element state
    element_transition: transitions.LayoutTransition,
    initial_position: Vec2,
    initial_size: Vec2,

    pub fn init(
        allocator: std.mem.Allocator,
        initial_position: Vec2,
        initial_size: Vec2,
    ) AnimationSequence {
        const timing = transitions.TimingConfig{ .duration = 1.0 };

        return AnimationSequence{
            .allocator = allocator,
            .steps = std.ArrayList(AnimationStep).init(allocator),
            .current_step = null,
            .sequence_time = 0.0,
            .is_playing = false,
            .is_looping = false,
            .element_transition = transitions.LayoutTransition.init(initial_position, initial_size, timing),
            .initial_position = initial_position,
            .initial_size = initial_size,
        };
    }

    pub fn deinit(self: *AnimationSequence) void {
        self.steps.deinit();
    }

    /// Add animation step to sequence
    pub fn addStep(self: *AnimationSequence, step: AnimationStep) !void {
        try self.steps.append(step);

        // Sort steps by start time
        std.sort.pdq(AnimationStep, self.steps.items, {}, stepLessThan);
    }

    fn stepLessThan(_: void, a: AnimationStep, b: AnimationStep) bool {
        return a.start_time < b.start_time;
    }

    /// Start playing the sequence
    pub fn play(self: *AnimationSequence) void {
        self.is_playing = true;
        self.sequence_time = 0.0;
        self.current_step = null;

        // Reset to initial state
        self.element_transition.position.current_value = self.initial_position;
        self.element_transition.size.current_value = self.initial_size;
        self.element_transition.opacity.current_value = 1.0;
        self.element_transition.rotation.current_value = 0.0;
        self.element_transition.scale.current_value = 1.0;
    }

    /// Stop playing the sequence
    pub fn stop(self: *AnimationSequence) void {
        self.is_playing = false;
        self.current_step = null;
        self.element_transition.cancel();
    }

    /// Pause the sequence
    pub fn pause(self: *AnimationSequence) void {
        self.is_playing = false;
    }

    /// Resume the sequence
    pub fn resumeSequence(self: *AnimationSequence) void {
        self.is_playing = true;
    }

    /// Set whether sequence should loop
    pub fn setLooping(self: *AnimationSequence, looping: bool) void {
        self.is_looping = looping;
    }

    /// Update sequence animation
    pub fn update(self: *AnimationSequence, delta_time: f32) void {
        if (!self.is_playing) return;

        self.sequence_time += delta_time;

        // Check for sequence completion
        if (self.steps.items.len > 0) {
            const last_step = self.steps.items[self.steps.items.len - 1];
            if (self.sequence_time >= last_step.getEndTime()) {
                if (self.is_looping) {
                    self.play(); // Restart
                    return;
                } else {
                    self.stop();
                    return;
                }
            }
        }

        // Find and execute active steps
        for (self.steps.items, 0..) |step, i| {
            if (self.sequence_time >= step.start_time and
                self.sequence_time <= step.getEndTime())
            {
                self.executeStep(step, i);
            }
        }

        // Update transitions
        self.element_transition.update(delta_time);
    }

    /// Execute a specific animation step
    fn executeStep(self: *AnimationSequence, step: AnimationStep, step_index: usize) void {
        // Check if this is a new step
        if (self.current_step != step_index) {
            self.current_step = step_index;
            self.startStep(step);
        }
    }

    /// Start executing a step
    fn startStep(self: *AnimationSequence, step: AnimationStep) void {
        // Update timing configuration
        const timing = transitions.TimingConfig{
            .duration = step.duration,
            .easing = step.easing,
        };

        switch (step.animation_type) {
            .position => {
                self.element_transition.position.timing = timing;
                self.element_transition.position.setTarget(step.target.position);
            },
            .size => {
                self.element_transition.size.timing = timing;
                self.element_transition.size.setTarget(step.target.size);
            },
            .opacity => {
                self.element_transition.opacity.timing = timing;
                self.element_transition.opacity.setTarget(step.target.opacity);
            },
            .rotation => {
                self.element_transition.rotation.timing = timing;
                self.element_transition.rotation.setTarget(step.target.rotation);
            },
            .scale => {
                self.element_transition.scale.timing = timing;
                self.element_transition.scale.setTarget(step.target.scale);
            },
            .layout => {
                self.element_transition.position.timing = timing;
                self.element_transition.size.timing = timing;
                self.element_transition.position.setTarget(step.target.layout.position);
                self.element_transition.size.setTarget(step.target.layout.size);
            },
            .fade_in => {
                self.element_transition.opacity.timing = timing;
                self.element_transition.opacity.setTarget(step.target.fade_in);
            },
            .fade_out => {
                self.element_transition.opacity.timing = timing;
                self.element_transition.opacity.setTarget(step.target.fade_out);
            },
            .slide_in_left => {
                const current_pos = self.element_transition.position.current_value;
                const target_pos = Vec2{
                    .x = current_pos.x + step.target.slide_in_left,
                    .y = current_pos.y,
                };
                self.element_transition.position.timing = timing;
                self.element_transition.position.setTarget(target_pos);
            },
            .slide_in_right => {
                const current_pos = self.element_transition.position.current_value;
                const target_pos = Vec2{
                    .x = current_pos.x - step.target.slide_in_right,
                    .y = current_pos.y,
                };
                self.element_transition.position.timing = timing;
                self.element_transition.position.setTarget(target_pos);
            },
            .slide_in_up => {
                const current_pos = self.element_transition.position.current_value;
                const target_pos = Vec2{
                    .x = current_pos.x,
                    .y = current_pos.y + step.target.slide_in_up,
                };
                self.element_transition.position.timing = timing;
                self.element_transition.position.setTarget(target_pos);
            },
            .slide_in_down => {
                const current_pos = self.element_transition.position.current_value;
                const target_pos = Vec2{
                    .x = current_pos.x,
                    .y = current_pos.y - step.target.slide_in_down,
                };
                self.element_transition.position.timing = timing;
                self.element_transition.position.setTarget(target_pos);
            },
            .scale_in => {
                self.element_transition.scale.timing = timing;
                self.element_transition.scale.setTarget(step.target.scale_in);
            },
            .scale_out => {
                self.element_transition.scale.timing = timing;
                self.element_transition.scale.setTarget(step.target.scale_out);
            },
            // TODO: Implement remaining animation types
            else => {},
        }

        // Start the relevant transitions
        switch (step.animation_type) {
            .position, .slide_in_left, .slide_in_right, .slide_in_up, .slide_in_down, .slide_out_left, .slide_out_right, .slide_out_up, .slide_out_down => {
                self.element_transition.position.start();
            },
            .size => {
                self.element_transition.size.start();
            },
            .opacity, .fade_in, .fade_out => {
                self.element_transition.opacity.start();
            },
            .rotation => {
                self.element_transition.rotation.start();
            },
            .scale, .scale_in, .scale_out => {
                self.element_transition.scale.start();
            },
            .layout => {
                self.element_transition.position.start();
                self.element_transition.size.start();
            },
            else => {},
        }
    }

    /// Get current animated state
    pub fn getCurrentState(self: *const AnimationSequence) springs.LayoutState {
        return self.element_transition.getCurrentState();
    }

    /// Get sequence duration
    pub fn getDuration(self: *const AnimationSequence) f32 {
        if (self.steps.items.len == 0) return 0.0;

        var max_end_time: f32 = 0.0;
        for (self.steps.items) |step| {
            max_end_time = @max(max_end_time, step.getEndTime());
        }
        return max_end_time;
    }

    /// Check if sequence is complete
    pub fn isComplete(self: *const AnimationSequence) bool {
        return !self.is_playing and self.sequence_time >= self.getDuration();
    }
};

/// Timeline for coordinating multiple sequences
pub const AnimationTimeline = struct {
    allocator: std.mem.Allocator,
    sequences: std.ArrayList(*AnimationSequence),
    timeline_time: f32,
    is_playing: bool,
    is_looping: bool,

    pub fn init(allocator: std.mem.Allocator) AnimationTimeline {
        return AnimationTimeline{
            .allocator = allocator,
            .sequences = std.ArrayList(*AnimationSequence).init(allocator),
            .timeline_time = 0.0,
            .is_playing = false,
            .is_looping = false,
        };
    }

    pub fn deinit(self: *AnimationTimeline) void {
        self.sequences.deinit();
    }

    /// Add sequence to timeline
    pub fn addSequence(self: *AnimationTimeline, sequence: *AnimationSequence) !void {
        try self.sequences.append(sequence);
    }

    /// Start playing all sequences
    pub fn play(self: *AnimationTimeline) void {
        self.is_playing = true;
        self.timeline_time = 0.0;

        for (self.sequences.items) |sequence| {
            sequence.play();
        }
    }

    /// Stop all sequences
    pub fn stop(self: *AnimationTimeline) void {
        self.is_playing = false;

        for (self.sequences.items) |sequence| {
            sequence.stop();
        }
    }

    /// Update all sequences
    pub fn update(self: *AnimationTimeline, delta_time: f32) void {
        if (!self.is_playing) return;

        self.timeline_time += delta_time;

        // Update all sequences
        for (self.sequences.items) |sequence| {
            sequence.update(delta_time);
        }

        // Check for completion
        if (self.isComplete()) {
            if (self.is_looping) {
                self.play(); // Restart
            } else {
                self.stop();
            }
        }
    }

    /// Set looping behavior
    pub fn setLooping(self: *AnimationTimeline, looping: bool) void {
        self.is_looping = looping;

        // Update all sequences
        for (self.sequences.items) |sequence| {
            sequence.setLooping(looping);
        }
    }

    /// Check if all sequences are complete
    pub fn isComplete(self: *const AnimationTimeline) bool {
        for (self.sequences.items) |sequence| {
            if (!sequence.isComplete()) {
                return false;
            }
        }
        return true;
    }

    /// Get timeline duration (longest sequence)
    pub fn getDuration(self: *const AnimationTimeline) f32 {
        var max_duration: f32 = 0.0;
        for (self.sequences.items) |sequence| {
            max_duration = @max(max_duration, sequence.getDuration());
        }
        return max_duration;
    }
};

/// Common animation sequence builders
pub const SequenceBuilder = struct {
    /// Create fade in animation
    pub fn fadeIn(
        allocator: std.mem.Allocator,
        position: Vec2,
        size: Vec2,
        duration: f32,
    ) !AnimationSequence {
        var sequence = AnimationSequence.init(allocator, position, size);

        // Start with opacity 0, animate to 1
        sequence.element_transition.opacity.current_value = 0.0;

        try sequence.addStep(AnimationStep{
            .start_time = 0.0,
            .duration = duration,
            .animation_type = .fade_in,
            .target = .{ .fade_in = 1.0 },
            .easing = .ease_out_cubic,
        });

        return sequence;
    }

    /// Create slide in from left animation
    pub fn slideInLeft(
        allocator: std.mem.Allocator,
        position: Vec2,
        size: Vec2,
        distance: f32,
        duration: f32,
    ) !AnimationSequence {
        var sequence = AnimationSequence.init(allocator, position, size);

        // Start offset to the left
        sequence.element_transition.position.current_value = Vec2{
            .x = position.x - distance,
            .y = position.y,
        };

        try sequence.addStep(AnimationStep{
            .start_time = 0.0,
            .duration = duration,
            .animation_type = .slide_in_left,
            .target = .{ .slide_in_left = distance },
            .easing = .ease_out_cubic,
        });

        return sequence;
    }

    /// Create scale in animation
    pub fn scaleIn(
        allocator: std.mem.Allocator,
        position: Vec2,
        size: Vec2,
        duration: f32,
    ) !AnimationSequence {
        var sequence = AnimationSequence.init(allocator, position, size);

        // Start with scale 0
        sequence.element_transition.scale.current_value = 0.0;

        try sequence.addStep(AnimationStep{
            .start_time = 0.0,
            .duration = duration,
            .animation_type = .scale_in,
            .target = .{ .scale_in = 1.0 },
            .easing = .ease_out_back,
        });

        return sequence;
    }
};

// Tests
test "animation step timing" {
    const testing = std.testing;

    const step = AnimationStep{
        .start_time = 1.0,
        .duration = 0.5,
        .animation_type = .position,
        .target = .{ .position = Vec2{ .x = 100.0, .y = 50.0 } },
    };

    try testing.expect(step.getEndTime() == 1.5);
}

test "animation sequence basic playback" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const initial_pos = Vec2{ .x = 0.0, .y = 0.0 };
    const initial_size = Vec2{ .x = 100.0, .y = 50.0 };

    var sequence = AnimationSequence.init(allocator, initial_pos, initial_size);
    defer sequence.deinit();

    // Add a position animation step
    try sequence.addStep(AnimationStep{
        .start_time = 0.0,
        .duration = 1.0,
        .animation_type = .position,
        .target = .{ .position = Vec2{ .x = 100.0, .y = 100.0 } },
    });

    try testing.expect(sequence.getDuration() == 1.0);

    sequence.play();
    try testing.expect(sequence.is_playing);

    // Update partway through
    sequence.update(0.5);
    const state = sequence.getCurrentState();

    // Should be partway to target
    try testing.expect(state.position.x > 0.0 and state.position.x < 100.0);

    // Complete the animation
    sequence.update(0.5);
    // Note: Due to easing, we need to check if it's close to the target
    const final_state = sequence.getCurrentState();
    try testing.expect(@abs(final_state.position.x - 100.0) < 10.0);
}

test "sequence builder fade in" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const position = Vec2{ .x = 50.0, .y = 100.0 };
    const size = Vec2{ .x = 200.0, .y = 150.0 };

    var sequence = try SequenceBuilder.fadeIn(allocator, position, size, 0.5);
    defer sequence.deinit();

    try testing.expect(sequence.steps.items.len == 1);
    try testing.expect(sequence.getDuration() == 0.5);

    // Should start with opacity 0
    try testing.expect(sequence.element_transition.opacity.current_value == 0.0);

    sequence.play();
    sequence.update(0.5); // Complete the animation

    const state = sequence.getCurrentState();
    try testing.expect(@abs(state.opacity - 1.0) < 0.1);
}
