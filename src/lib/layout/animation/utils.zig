/// Animation utility functions and type selection
///
/// This module provides utilities for choosing appropriate animation types
/// and other helper functions for the animation system.

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
