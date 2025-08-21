/// Layout animation system
///
/// This module provides comprehensive animation support for layout properties,
/// including springs, transitions, and animation sequencing.
pub const springs = @import("springs.zig");
pub const transitions = @import("transitions.zig");
pub const sequencer = @import("sequencer.zig");

// Re-export commonly used types
pub const SpringConfig = springs.SpringConfig;
pub const Spring1D = springs.Spring1D;
pub const Spring2D = springs.Spring2D;
pub const LayoutSpring = springs.LayoutSpring;
pub const LayoutState = springs.LayoutState;
pub const SpringPresets = springs.SpringPresets;

pub const EasingFunction = transitions.EasingFunction;
pub const TimingConfig = transitions.TimingConfig;
pub const TransitionState = transitions.TransitionState;
pub const Transition = transitions.Transition;
pub const FloatTransition = transitions.FloatTransition;
pub const Vec2Transition = transitions.Vec2Transition;
pub const LayoutTransition = transitions.LayoutTransition;
pub const TransitionGroup = transitions.TransitionGroup;
pub const TimingPresets = transitions.TimingPresets;

pub const AnimationStep = sequencer.AnimationStep;
pub const AnimationSequence = sequencer.AnimationSequence;
pub const AnimationTimeline = sequencer.AnimationTimeline;
pub const SequenceBuilder = sequencer.SequenceBuilder;

// Animation type selection utilities
pub const AnimationType = enum {
    spring,
    transition,
    sequence,
};

/// Choose appropriate animation type based on requirements
pub fn recommendAnimationType(
    needs_physics: bool,
    needs_precise_timing: bool,
    needs_coordination: bool,
) AnimationType {
    if (needs_coordination) return .sequence;
    if (needs_physics) return .spring;
    if (needs_precise_timing) return .transition;
    return .spring; // Default to springs for natural feel
}

/// Animation manager for coordinating all animation types
pub const AnimationManager = struct {
    springs: std.ArrayList(LayoutSpring),
    transitions: std.ArrayList(LayoutTransition),
    sequences: std.ArrayList(AnimationSequence),
    timelines: std.ArrayList(AnimationTimeline),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AnimationManager {
        return AnimationManager{
            .springs = std.ArrayList(LayoutSpring).init(allocator),
            .transitions = std.ArrayList(LayoutTransition).init(allocator),
            .sequences = std.ArrayList(AnimationSequence).init(allocator),
            .timelines = std.ArrayList(AnimationTimeline).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AnimationManager) void {
        // Clean up sequences
        for (self.sequences.items) |*sequence| {
            sequence.deinit();
        }
        self.sequences.deinit();

        // Clean up timelines
        for (self.timelines.items) |*timeline| {
            timeline.deinit();
        }
        self.timelines.deinit();

        self.springs.deinit();
        self.transitions.deinit();
    }

    /// Update all animations
    pub fn update(self: *AnimationManager, delta_time: f32) void {
        // Update springs
        for (self.springs.items) |*spring| {
            spring.update(delta_time);
        }

        // Update transitions
        for (self.transitions.items) |*transition| {
            transition.update(delta_time);
        }

        // Update sequences
        for (self.sequences.items) |*sequence| {
            sequence.update(delta_time);
        }

        // Update timelines
        for (self.timelines.items) |*timeline| {
            timeline.update(delta_time);
        }

        // Clean up completed animations
        self.cleanupCompleted();
    }

    /// Remove completed and idle animations
    fn cleanupCompleted(self: *AnimationManager) void {
        // Remove completed transitions
        var i: usize = 0;
        while (i < self.transitions.items.len) {
            if (self.transitions.items[i].isComplete()) {
                _ = self.transitions.swapRemove(i);
            } else {
                i += 1;
            }
        }

        // Remove completed sequences
        i = 0;
        while (i < self.sequences.items.len) {
            if (self.sequences.items[i].isComplete()) {
                self.sequences.items[i].deinit();
                _ = self.sequences.swapRemove(i);
            } else {
                i += 1;
            }
        }

        // Remove completed timelines
        i = 0;
        while (i < self.timelines.items.len) {
            if (self.timelines.items[i].isComplete()) {
                self.timelines.items[i].deinit();
                _ = self.timelines.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    /// Add a new spring animation
    pub fn addSpring(self: *AnimationManager, spring: LayoutSpring) !*LayoutSpring {
        try self.springs.append(spring);
        return &self.springs.items[self.springs.items.len - 1];
    }

    /// Add a new transition animation
    pub fn addTransition(self: *AnimationManager, transition: LayoutTransition) !*LayoutTransition {
        try self.transitions.append(transition);
        return &self.transitions.items[self.transitions.items.len - 1];
    }

    /// Add a new sequence animation
    pub fn addSequence(self: *AnimationManager, sequence: AnimationSequence) !*AnimationSequence {
        try self.sequences.append(sequence);
        return &self.sequences.items[self.sequences.items.len - 1];
    }

    /// Add a new timeline
    pub fn addTimeline(self: *AnimationManager, timeline: AnimationTimeline) !*AnimationTimeline {
        try self.timelines.append(timeline);
        return &self.timelines.items[self.timelines.items.len - 1];
    }

    /// Get animation counts for debugging
    pub fn getAnimationCounts(self: *const AnimationManager) AnimationCounts {
        return AnimationCounts{
            .springs = self.springs.items.len,
            .transitions = self.transitions.items.len,
            .sequences = self.sequences.items.len,
            .timelines = self.timelines.items.len,
        };
    }

    pub const AnimationCounts = struct {
        springs: usize,
        transitions: usize,
        sequences: usize,
        timelines: usize,

        pub fn total(self: AnimationCounts) usize {
            return self.springs + self.transitions + self.sequences + self.timelines;
        }
    };
};

const std = @import("std");

// Tests
test "animation type recommendations" {
    const testing = std.testing;

    // Should recommend springs for physics-based animations
    try testing.expect(recommendAnimationType(true, false, false) == .spring);

    // Should recommend transitions for precise timing
    try testing.expect(recommendAnimationType(false, true, false) == .transition);

    // Should recommend sequences for coordination
    try testing.expect(recommendAnimationType(false, false, true) == .sequence);

    // Default should be springs
    try testing.expect(recommendAnimationType(false, false, false) == .spring);
}
