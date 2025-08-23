const std = @import("std");
const c = @import("sdl.zig");
const window_mod = @import("window.zig");
const font_manager = @import("../font/manager.zig");
const loggers = @import("../debug/loggers.zig");

const FontManager = font_manager.FontManager;

/// Common error types for resource initialization
pub const ResourceError = error{
    RendererInitFailed,
    FontManagerInitFailed,
    WindowCreationFailed,
    OutOfMemory,
};

/// Font manager resource handle for sharing across multiple renderers
pub const SharedFontManager = struct {
    font_manager: *FontManager,
    allocator: std.mem.Allocator,
    ref_count: u32,

    pub fn init(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice) ResourceError!*SharedFontManager {
        const shared = allocator.create(SharedFontManager) catch {
            return ResourceError.OutOfMemory;
        };

        const fm = allocator.create(FontManager) catch {
            allocator.destroy(shared);
            return ResourceError.OutOfMemory;
        };

        fm.* = FontManager.init(allocator, device) catch |err| {
            const platform_log = loggers.getPlatformLog();
            platform_log.err("resource_manager", "Failed to initialize shared FontManager: {}", .{err});
            allocator.destroy(fm);
            allocator.destroy(shared);
            return ResourceError.FontManagerInitFailed;
        };

        shared.* = SharedFontManager{
            .font_manager = fm,
            .allocator = allocator,
            .ref_count = 1,
        };

        return shared;
    }

    pub fn addRef(self: *SharedFontManager) void {
        self.ref_count += 1;
    }

    pub fn release(self: *SharedFontManager) void {
        self.ref_count -= 1;
        if (self.ref_count == 0) {
            self.font_manager.deinit();
            self.allocator.destroy(self.font_manager);
            self.allocator.destroy(self);
        }
    }

    pub fn get(self: *const SharedFontManager) *FontManager {
        return self.font_manager;
    }
};

/// Error handling utilities for resource initialization
pub const ResourceErrorHandler = struct {
    pub fn logAndHandleError(err: anyerror, context: []const u8) ResourceError {
        const platform_log = loggers.getPlatformLog();

        switch (err) {
            error.OutOfMemory => {
                platform_log.err("resource_manager", "Out of memory during {s}", .{context});
                return ResourceError.OutOfMemory;
            },
            error.WindowCreationFailed => {
                platform_log.err("resource_manager", "Window creation failed during {s}", .{context});
                return ResourceError.WindowCreationFailed;
            },
            else => {
                platform_log.err("resource_manager", "Unexpected error during {s}: {}", .{ context, err });
                return ResourceError.RendererInitFailed;
            },
        }
    }

    pub fn tryWithCleanup(comptime T: type, init_fn: anytype, cleanup_fn: anytype, context: []const u8) ResourceError!T {
        return init_fn() catch |err| {
            cleanup_fn();
            return logAndHandleError(err, context);
        };
    }
};

// NOTE: PlatformResources was removed as part of WindowGPU architectural cleanup
// Individual resource types (like SharedFontManager) are still available
