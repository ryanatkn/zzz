/// Layout animation system
///
/// This module provides comprehensive animation support for layout properties,
/// including springs, transitions, and animation sequencing.
pub const springs = @import("springs.zig");
pub const transitions = @import("transitions.zig");
pub const sequencer = @import("sequencer.zig");
pub const manager = @import("manager.zig");
pub const utils = @import("utils.zig");

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

// Re-export manager and utilities
pub const AnimationManager = manager.AnimationManager;
pub const AnimationType = utils.AnimationType;
pub const recommendAnimationType = utils.recommendAnimationType;

// Re-export tests
pub usingnamespace @import("tests.zig");
