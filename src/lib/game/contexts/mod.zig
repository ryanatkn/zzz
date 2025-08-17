/// Context system for passing shared state through update cycles
/// Provides a clean way to pass frame-specific data without global state
/// 
/// This system enables consistent parameter passing across game systems and
/// reduces function signature complexity.

// Core context types
pub const UpdateContext = @import("update_context.zig").UpdateContext;
pub const InputContext = @import("input_context.zig").InputContext;
pub const GraphicsContext = @import("graphics_context.zig").GraphicsContext;
pub const PhysicsContext = @import("physics_context.zig").PhysicsContext;

// Unified context types
pub const GameContext = @import("game_context.zig").GameContext;
pub const SimpleGameContext = @import("game_context.zig").SimpleGameContext;
pub const GameContextUtils = @import("game_context.zig").GameContextUtils;

// Input system types (re-exported for convenience)
pub const MouseButtons = @import("input_context.zig").MouseButtons;
pub const ModifierKeys = @import("input_context.zig").ModifierKeys;
pub const KeySet = @import("input_context.zig").KeySet;

// Builder and utilities
pub const ContextBuilder = @import("context_utils.zig").ContextBuilder;
pub const ContextUtils = @import("context_utils.zig").ContextUtils;
pub const validateContext = @import("context_utils.zig").validateContext;
pub const validateContextRuntime = @import("context_utils.zig").validateContextRuntime;

// Common usage patterns
pub const contexts = struct {
    /// Create a basic update context
    pub fn createUpdate(allocator: std.mem.Allocator, delta_time: f32, frame_number: u64) UpdateContext {
        return UpdateContext.init(allocator, delta_time, frame_number);
    }

    /// Create an input context with platform integration
    pub fn createInput(base: UpdateContext, platform_input: anytype) InputContext {
        return InputContext.init(base).withPlatformInput(platform_input);
    }

    /// Create a graphics context with camera integration
    pub fn createGraphics(base: UpdateContext, screen_width: f32, screen_height: f32, camera: anytype) GraphicsContext {
        return GraphicsContext.init(base, screen_width, screen_height).withEngineCamera(camera);
    }

    /// Create a physics context with world settings
    pub fn createPhysics(base: UpdateContext, gravity: @import("../../math/mod.zig").Vec2) PhysicsContext {
        return PhysicsContext.init(base).withGravity(gravity);
    }
};

const std = @import("std");