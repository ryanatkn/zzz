const std = @import("std");
const c = @import("sdl.zig");
const window_mod = @import("window.zig");
const font_manager = @import("../font/manager.zig");

const WindowGPU = window_mod.WindowGPU;
const FontManager = font_manager.FontManager;

/// Common error types for resource initialization  
pub const ResourceError = error{
    RendererInitFailed,
    FontManagerInitFailed,
    WindowCreationFailed,
    DeviceCreationFailed,
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
            const log = std.log.scoped(.resource_manager);
            log.err("Failed to initialize shared FontManager: {}", .{err});
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
        const log = std.log.scoped(.resource_manager);

        switch (err) {
            error.OutOfMemory => {
                log.err("Out of memory during {s}", .{context});
                return ResourceError.OutOfMemory;
            },
            error.DeviceCreationFailed => {
                log.err("GPU device creation failed during {s}", .{context});
                return ResourceError.DeviceCreationFailed;
            },
            error.WindowCreationFailed => {
                log.err("Window creation failed during {s}", .{context});
                return ResourceError.WindowCreationFailed;
            },
            else => {
                log.err("Unexpected error during {s}: {}", .{ context, err });
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

/// Basic platform resources without rendering dependency
pub const PlatformResources = struct {
    window_gpu: WindowGPU,
    font_manager: *FontManager,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, window_config: window_mod.WindowConfig) ResourceError!PlatformResources {
        const window_gpu = window_mod.WindowGPU.init(window_config) catch |err| {
            return ResourceErrorHandler.logAndHandleError(err, "window/GPU initialization");
        };
        errdefer window_gpu.deinit();

        const fm = allocator.create(FontManager) catch {
            return ResourceError.OutOfMemory;
        };

        fm.* = FontManager.init(allocator, window_gpu.device) catch |err| {
            const log = std.log.scoped(.resource_manager);
            log.err("Failed to initialize FontManager: {}", .{err});
            allocator.destroy(fm);
            return ResourceError.FontManagerInitFailed;
        };

        return PlatformResources{
            .window_gpu = window_gpu,
            .font_manager = fm,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PlatformResources) void {
        self.font_manager.deinit();
        self.allocator.destroy(self.font_manager);
        self.window_gpu.deinit();
    }

    /// Get the window pointer
    pub fn getWindow(self: *const PlatformResources) *c.sdl.SDL_Window {
        return self.window_gpu.window;
    }

    /// Get the GPU device pointer
    pub fn getDevice(self: *const PlatformResources) *c.sdl.SDL_GPUDevice {
        return self.window_gpu.device;
    }
};