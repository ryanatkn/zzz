const types = @import("types.zig");

const Vec2 = types.Vec2;

/// Viewport interface for screen-to-world coordinate conversion
/// This breaks the circular dependency between platform/input and rendering/camera
pub const Viewport = struct {
    const Self = @This();

    // Function pointer for screen to world conversion
    screenToWorldFn: *const fn (*const anyopaque, Vec2) Vec2,
    impl: *const anyopaque,

    pub fn screenToWorld(self: Self, screen_pos: Vec2) Vec2 {
        return self.screenToWorldFn(self.impl, screen_pos);
    }
};

/// Create a viewport interface from any object with screenToWorld method
pub fn createViewport(viewport_impl: anytype) Viewport {
    const T = @TypeOf(viewport_impl);
    const impl = struct {
        fn screenToWorld(ptr: *const anyopaque, screen_pos: Vec2) Vec2 {
            const self: *const T = @ptrCast(@alignCast(ptr));
            // Use the safe version that handles errors gracefully
            return self.*.screenToWorldSafe(screen_pos);
        }
    };

    return Viewport{
        .screenToWorldFn = impl.screenToWorld,
        .impl = viewport_impl,
    };
}