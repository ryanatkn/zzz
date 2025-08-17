/// Context utilities and builder for creating complex contexts
const std = @import("std");
const UpdateContext = @import("update_context.zig").UpdateContext;
const InputContext = @import("input_context.zig").InputContext;
const GraphicsContext = @import("graphics_context.zig").GraphicsContext;
const PhysicsContext = @import("physics_context.zig").PhysicsContext;

// ========================
// CONTEXT BUILDER
// ========================

/// Builder for creating complex contexts with method chaining
pub const ContextBuilder = struct {
    allocator: std.mem.Allocator,
    delta_time: f32,
    frame_number: u64,
    is_paused: bool = false,

    pub fn init(allocator: std.mem.Allocator, delta_time: f32, frame_number: u64) ContextBuilder {
        return .{
            .allocator = allocator,
            .delta_time = delta_time,
            .frame_number = frame_number,
        };
    }

    pub fn setPaused(self: ContextBuilder, paused: bool) ContextBuilder {
        var result = self;
        result.is_paused = paused;
        return result;
    }

    pub fn buildUpdate(self: ContextBuilder) UpdateContext {
        return UpdateContext.init(self.allocator, self.delta_time, self.frame_number)
            .withPause(self.is_paused);
    }

    pub fn buildInput(self: ContextBuilder) InputContext {
        return InputContext.init(self.buildUpdate());
    }

    pub fn buildGraphics(self: ContextBuilder, screen_width: f32, screen_height: f32) GraphicsContext {
        return GraphicsContext.init(self.buildUpdate(), screen_width, screen_height);
    }

    pub fn buildPhysics(self: ContextBuilder) PhysicsContext {
        return PhysicsContext.init(self.buildUpdate());
    }
};

// ========================
// CONTEXT UTILITIES
// ========================

/// Utility functions for working with contexts
pub const ContextUtils = struct {
    /// Extract base context from any specialized context
    pub fn extractBase(context: anytype) UpdateContext {
        const T = @TypeOf(context);
        
        // Handle GameContext types (they have an update field)
        if (@hasField(T, "update")) {
            return context.update;
        }
        
        return switch (T) {
            UpdateContext => context,
            InputContext => context.base,
            GraphicsContext => context.base,
            PhysicsContext => context.base,
            else => @compileError("Unsupported context type: " ++ @typeName(T)),
        };
    }

    /// Check if any context indicates the game is paused
    pub fn isPaused(context: anytype) bool {
        return extractBase(context).is_paused;
    }

    /// Get delta time from any context
    pub fn deltaTime(context: anytype) f32 {
        return extractBase(context).delta_time;
    }

    /// Get effective delta time (0 if paused) from any context
    pub fn effectiveDeltaTime(context: anytype) f32 {
        return extractBase(context).effectiveDeltaTime();
    }

    /// Get frame number from any context
    pub fn frameNumber(context: anytype) u64 {
        return extractBase(context).frame_number;
    }

    /// Get frame allocator from any context
    pub fn frameAllocator(context: anytype) std.mem.Allocator {
        return extractBase(context).frame_allocator;
    }

    /// Get frame elapsed time from any context
    pub fn frameElapsedSec(context: anytype) f32 {
        return extractBase(context).frameElapsedSec();
    }

    /// Get frame elapsed time in milliseconds from any context
    pub fn frameElapsedMs(context: anytype) f32 {
        return extractBase(context).frameElapsedMs();
    }
};

// ========================
// CONTEXT VALIDATION
// ========================

/// Compile-time context validation
pub fn validateContext(comptime ContextType: type) void {
    switch (ContextType) {
        UpdateContext, InputContext, GraphicsContext, PhysicsContext => {},
        else => @compileError("Invalid context type: " ++ @typeName(ContextType)),
    }
}

/// Runtime context validation
pub fn validateContextRuntime(context: anytype) !void {
    const base = ContextUtils.extractBase(context);

    if (base.delta_time < 0) {
        return error.InvalidDeltaTime;
    }

    if (base.delta_time > 1.0) {
        return error.DeltaTimeTooLarge;
    }
}

// ========================
// TESTS
// ========================

test "basic context creation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const context = UpdateContext.init(allocator, 0.016, 42);

    try std.testing.expectApproxEqAbs(@as(f32, 0.016), context.delta_time, 0.001);
    try std.testing.expect(context.frame_number == 42);
    try std.testing.expect(!context.is_paused);
}

test "context builder" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const builder = ContextBuilder.init(allocator, 0.016, 100).setPaused(true);

    const update_context = builder.buildUpdate();
    try std.testing.expect(update_context.is_paused);

    const input_context = builder.buildInput();
    try std.testing.expect(input_context.base.is_paused);
}

test "context utilities" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const base_context = UpdateContext.init(allocator, 0.02, 50).withPause(true);
    const input_context = InputContext.init(base_context);

    try std.testing.expect(ContextUtils.isPaused(input_context));
    try std.testing.expectApproxEqAbs(@as(f32, 0.02), ContextUtils.deltaTime(input_context), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), ContextUtils.effectiveDeltaTime(input_context), 0.001);
    try std.testing.expect(ContextUtils.frameNumber(input_context) == 50);
}

test "context validation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // Valid context
    const valid_context = UpdateContext.init(allocator, 0.016, 1);
    try validateContextRuntime(valid_context);

    // Invalid delta time
    const invalid_context = UpdateContext.init(allocator, -0.1, 1);
    try std.testing.expectError(error.InvalidDeltaTime, validateContextRuntime(invalid_context));
}