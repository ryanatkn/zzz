/// Update context system for passing shared state through update cycles
/// Provides a clean way to pass frame-specific data without global state

const std = @import("std");
// Simple time representation for standalone testing
const Time = struct {
    start_time: i64,
    
    pub fn now() Time {
        return .{ .start_time = std.time.milliTimestamp() };
    }
    
    pub fn getElapsedSec(self: Time) f32 {
        const current_time = std.time.milliTimestamp();
        const elapsed_ms = current_time - self.start_time;
        return @as(f32, @floatFromInt(elapsed_ms)) / 1000.0;
    }
};

// ========================
// CORE CONTEXT TYPES
// ========================

/// Base context for all update operations
pub const UpdateContext = struct {
    /// Time information for this frame
    time: Time,
    /// Delta time since last frame in seconds
    delta_time: f32,
    /// Current frame number
    frame_number: u64,
    /// Is the game paused?
    is_paused: bool,
    /// Allocator for temporary allocations during this frame
    frame_allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, delta_time: f32, frame_number: u64) UpdateContext {
        return .{
            .time = Time.now(),
            .delta_time = delta_time,
            .frame_number = frame_number,
            .is_paused = false,
            .frame_allocator = allocator,
        };
    }

    pub fn withPause(self: UpdateContext, paused: bool) UpdateContext {
        var result = self;
        result.is_paused = paused;
        return result;
    }

    /// Get effective delta time (0 if paused)
    pub fn effectiveDeltaTime(self: UpdateContext) f32 {
        return if (self.is_paused) 0.0 else self.delta_time;
    }

    /// Get time elapsed since start in seconds
    pub fn totalElapsed(self: UpdateContext) f32 {
        return self.time.getElapsedSec();
    }
};

/// Input context for update operations that need input state
pub const InputContext = struct {
    base: UpdateContext,
    
    // Mouse state
    mouse_position: struct { x: f32, y: f32 },
    mouse_delta: struct { x: f32, y: f32 },
    mouse_buttons: MouseButtons,
    mouse_wheel: f32,
    
    // Keyboard state
    keys_pressed: KeySet,
    keys_held: KeySet,
    keys_released: KeySet,
    
    // Modifiers
    modifiers: ModifierKeys,

    pub fn init(base_context: UpdateContext) InputContext {
        return .{
            .base = base_context,
            .mouse_position = .{ .x = 0, .y = 0 },
            .mouse_delta = .{ .x = 0, .y = 0 },
            .mouse_buttons = MouseButtons{},
            .mouse_wheel = 0,
            .keys_pressed = KeySet{},
            .keys_held = KeySet{},
            .keys_released = KeySet{},
            .modifiers = ModifierKeys{},
        };
    }

    pub fn withMousePosition(self: InputContext, x: f32, y: f32) InputContext {
        var result = self;
        result.mouse_position = .{ .x = x, .y = y };
        return result;
    }

    pub fn withMouseDelta(self: InputContext, dx: f32, dy: f32) InputContext {
        var result = self;
        result.mouse_delta = .{ .x = dx, .y = dy };
        return result;
    }
};

/// Graphics context for rendering operations
pub const GraphicsContext = struct {
    base: UpdateContext,
    
    // Screen dimensions
    screen_width: f32,
    screen_height: f32,
    
    // Camera state
    camera_position: struct { x: f32, y: f32 },
    camera_zoom: f32,
    
    // Viewport info
    viewport_bounds: struct {
        min_x: f32,
        min_y: f32,
        max_x: f32,
        max_y: f32,
    },

    pub fn init(base_context: UpdateContext, screen_width: f32, screen_height: f32) GraphicsContext {
        return .{
            .base = base_context,
            .screen_width = screen_width,
            .screen_height = screen_height,
            .camera_position = .{ .x = 0, .y = 0 },
            .camera_zoom = 1.0,
            .viewport_bounds = .{
                .min_x = -screen_width / 2.0,
                .min_y = -screen_height / 2.0,
                .max_x = screen_width / 2.0,
                .max_y = screen_height / 2.0,
            },
        };
    }

    pub fn withCamera(self: GraphicsContext, x: f32, y: f32, zoom: f32) GraphicsContext {
        var result = self;
        result.camera_position = .{ .x = x, .y = y };
        result.camera_zoom = zoom;
        
        // Update viewport bounds based on camera
        const world_width = result.screen_width / zoom;
        const world_height = result.screen_height / zoom;
        result.viewport_bounds = .{
            .min_x = x - world_width / 2.0,
            .min_y = y - world_height / 2.0,
            .max_x = x + world_width / 2.0,
            .max_y = y + world_height / 2.0,
        };
        
        return result;
    }

    /// Check if a point is visible in the current viewport
    pub fn isPointVisible(self: GraphicsContext, x: f32, y: f32) bool {
        return x >= self.viewport_bounds.min_x and x <= self.viewport_bounds.max_x and
               y >= self.viewport_bounds.min_y and y <= self.viewport_bounds.max_y;
    }

    /// Check if a circle is visible in the current viewport
    pub fn isCircleVisible(self: GraphicsContext, x: f32, y: f32, radius: f32) bool {
        return x + radius >= self.viewport_bounds.min_x and x - radius <= self.viewport_bounds.max_x and
               y + radius >= self.viewport_bounds.min_y and y - radius <= self.viewport_bounds.max_y;
    }
};

/// Physics context for physics update operations
pub const PhysicsContext = struct {
    base: UpdateContext,
    
    // Physics world settings
    gravity: struct { x: f32, y: f32 },
    time_scale: f32,
    
    // Collision settings
    collision_iterations: u32,
    position_iterations: u32,
    
    // Spatial partitioning info
    world_bounds: struct {
        min_x: f32,
        min_y: f32,
        max_x: f32,
        max_y: f32,
    },

    pub fn init(base_context: UpdateContext) PhysicsContext {
        return .{
            .base = base_context,
            .gravity = .{ .x = 0, .y = 0 },
            .time_scale = 1.0,
            .collision_iterations = 8,
            .position_iterations = 3,
            .world_bounds = .{
                .min_x = -1000,
                .min_y = -1000,
                .max_x = 1000,
                .max_y = 1000,
            },
        };
    }

    pub fn withGravity(self: PhysicsContext, x: f32, y: f32) PhysicsContext {
        var result = self;
        result.gravity = .{ .x = x, .y = y };
        return result;
    }

    pub fn withTimeScale(self: PhysicsContext, scale: f32) PhysicsContext {
        var result = self;
        result.time_scale = scale;
        return result;
    }

    /// Get effective delta time for physics (scaled and paused)
    pub fn physicseDeltaTime(self: PhysicsContext) f32 {
        return self.base.effectiveDeltaTime() * self.time_scale;
    }
};

// ========================
// INPUT TYPES
// ========================

/// Mouse button state
pub const MouseButtons = struct {
    left: bool = false,
    right: bool = false,
    middle: bool = false,
    x1: bool = false,
    x2: bool = false,

    pub fn any(self: MouseButtons) bool {
        return self.left or self.right or self.middle or self.x1 or self.x2;
    }

    pub fn primary(self: MouseButtons) bool {
        return self.left;
    }

    pub fn secondary(self: MouseButtons) bool {
        return self.right;
    }
};

/// Keyboard modifier keys
pub const ModifierKeys = struct {
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
    super: bool = false, // Windows/Cmd key

    pub fn any(self: ModifierKeys) bool {
        return self.ctrl or self.shift or self.alt or self.super;
    }
};

/// Set of keyboard keys (simple implementation)
pub const KeySet = struct {
    // Common keys used in games
    w: bool = false,
    a: bool = false,
    s: bool = false,
    d: bool = false,
    space: bool = false,
    enter: bool = false,
    escape: bool = false,
    tab: bool = false,
    
    // Number keys
    key_1: bool = false,
    key_2: bool = false,
    key_3: bool = false,
    key_4: bool = false,
    key_5: bool = false,
    key_6: bool = false,
    key_7: bool = false,
    key_8: bool = false,
    key_9: bool = false,
    key_0: bool = false,
    
    // Additional keys
    q: bool = false,
    e: bool = false,
    r: bool = false,
    f: bool = false,
    g: bool = false,
    h: bool = false,
    
    pub fn any(self: KeySet) bool {
        return self.w or self.a or self.s or self.d or self.space or
               self.enter or self.escape or self.tab or
               self.key_1 or self.key_2 or self.key_3 or self.key_4 or
               self.key_5 or self.key_6 or self.key_7 or self.key_8 or
               self.key_9 or self.key_0 or
               self.q or self.e or self.r or self.f or self.g or self.h;
    }

    /// Check if movement keys are pressed
    pub fn hasMovement(self: KeySet) bool {
        return self.w or self.a or self.s or self.d;
    }

    /// Check if spell keys are pressed
    pub fn hasSpellKeys(self: KeySet) bool {
        return self.key_1 or self.key_2 or self.key_3 or self.key_4 or
               self.q or self.e or self.r or self.f;
    }
};

// ========================
// CONTEXT BUILDERS
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

test "graphics context visibility" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    const base_context = UpdateContext.init(allocator, 0.016, 1);
    var graphics_context = GraphicsContext.init(base_context, 800, 600);
    graphics_context = graphics_context.withCamera(100, 100, 1.0);
    
    // Point at camera position should be visible
    try std.testing.expect(graphics_context.isPointVisible(100, 100));
    
    // Point far outside viewport should not be visible
    try std.testing.expect(!graphics_context.isPointVisible(1000, 1000));
    
    // Circle overlapping viewport should be visible
    try std.testing.expect(graphics_context.isCircleVisible(100, 100, 10));
}

test "input state" {
    const keys = KeySet{
        .w = true,
        .s = true,
        .key_1 = true,
    };
    
    try std.testing.expect(keys.any());
    try std.testing.expect(keys.hasMovement());
    try std.testing.expect(keys.hasSpellKeys());
    
    const mouse = MouseButtons{
        .left = true,
        .right = false,
    };
    
    try std.testing.expect(mouse.any());
    try std.testing.expect(mouse.primary());
    try std.testing.expect(!mouse.secondary());
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