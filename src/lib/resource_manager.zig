const std = @import("std");
const c = @import("c.zig");
const fonts = @import("fonts.zig");
const simple_gpu_renderer = @import("simple_gpu_renderer.zig");

const SimpleGPURenderer = simple_gpu_renderer.SimpleGPURenderer;
const FontManager = fonts.FontManager;

/// Common error types for resource initialization
pub const ResourceError = error{
    RendererInitFailed,
    FontManagerInitFailed,
    WindowCreationFailed,
    DeviceCreationFailed,
    OutOfMemory,
};

/// Common resource initialization result
pub const RendererResources = struct {
    gpu: SimpleGPURenderer,
    font_manager: *FontManager,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *RendererResources) void {
        self.font_manager.deinit();
        self.allocator.destroy(self.font_manager);
        self.gpu.deinit();
    }
};

/// Initialize common renderer resources (GPU + FontManager)
pub fn initRendererResources(allocator: std.mem.Allocator, window: *c.sdl.SDL_Window) ResourceError!RendererResources {
    var gpu = SimpleGPURenderer.init(allocator, window) catch |err| {
        const log = std.log.scoped(.resource_manager);
        log.err("Failed to initialize SimpleGPURenderer: {}", .{err});
        return ResourceError.RendererInitFailed;
    };
    
    var font_manager = allocator.create(FontManager) catch {
        gpu.deinit();
        return ResourceError.OutOfMemory;
    };
    
    font_manager.* = FontManager.init(allocator, gpu.device) catch |err| {
        const log = std.log.scoped(.resource_manager);
        log.err("Failed to initialize FontManager: {}", .{err});
        allocator.destroy(font_manager);
        gpu.deinit();
        return ResourceError.FontManagerInitFailed;
    };
    
    const log = std.log.scoped(.resource_manager);
    log.info("Renderer resources initialized successfully - GPU: {*}, FontManager: {*}", .{ &gpu, font_manager });
    
    return RendererResources{
        .gpu = gpu,
        .font_manager = font_manager,
        .allocator = allocator,
    };
}

/// Font manager resource handle for sharing across multiple renderers
pub const SharedFontManager = struct {
    font_manager: *FontManager,
    allocator: std.mem.Allocator,
    ref_count: u32,
    
    pub fn init(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice) ResourceError!*SharedFontManager {
        var shared = allocator.create(SharedFontManager) catch {
            return ResourceError.OutOfMemory;
        };
        
        var font_manager = allocator.create(FontManager) catch {
            allocator.destroy(shared);
            return ResourceError.OutOfMemory;
        };
        
        font_manager.* = FontManager.init(allocator, device) catch |err| {
            const log = std.log.scoped(.resource_manager);
            log.err("Failed to initialize shared FontManager: {}", .{err});
            allocator.destroy(font_manager);
            allocator.destroy(shared);
            return ResourceError.FontManagerInitFailed;
        };
        
        shared.* = SharedFontManager{
            .font_manager = font_manager,
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

/// Resource factory for creating consistent renderer configurations
pub const RendererFactory = struct {
    allocator: std.mem.Allocator,
    shared_font_manager: ?*SharedFontManager,
    
    pub fn init(allocator: std.mem.Allocator) RendererFactory {
        return RendererFactory{
            .allocator = allocator,
            .shared_font_manager = null,
        };
    }
    
    pub fn deinit(self: *RendererFactory) void {
        if (self.shared_font_manager) |shared| {
            shared.release();
            self.shared_font_manager = null;
        }
    }
    
    /// Create a renderer with isolated font manager
    pub fn createIsolatedRenderer(self: *RendererFactory, window: *c.sdl.SDL_Window) ResourceError!RendererResources {
        return initRendererResources(self.allocator, window);
    }
    
    /// Create a renderer that shares the font manager
    pub fn createSharedRenderer(self: *RendererFactory, window: *c.sdl.SDL_Window) ResourceError!SharedRendererResources {
        var gpu = SimpleGPURenderer.init(self.allocator, window) catch |err| {
            const log = std.log.scoped(.resource_manager);
            log.err("Failed to initialize SimpleGPURenderer for shared renderer: {}", .{err});
            return ResourceError.RendererInitFailed;
        };
        
        // Initialize shared font manager if needed
        if (self.shared_font_manager == null) {
            self.shared_font_manager = SharedFontManager.init(self.allocator, gpu.device) catch |err| {
                gpu.deinit();
                return err;
            };
        } else {
            self.shared_font_manager.?.addRef();
        }
        
        return SharedRendererResources{
            .gpu = gpu,
            .shared_font_manager = self.shared_font_manager.?,
            .allocator = self.allocator,
        };
    }
};

/// Renderer resources that share a font manager
pub const SharedRendererResources = struct {
    gpu: SimpleGPURenderer,
    shared_font_manager: *SharedFontManager,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *SharedRendererResources) void {
        self.shared_font_manager.release();
        self.gpu.deinit();
    }
    
    pub fn getFontManager(self: *const SharedRendererResources) *FontManager {
        return self.shared_font_manager.get();
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
    
    pub fn tryWithCleanup(
        comptime T: type,
        init_fn: anytype,
        cleanup_fn: anytype,
        context: []const u8
    ) ResourceError!T {
        return init_fn() catch |err| {
            cleanup_fn();
            return logAndHandleError(err, context);
        };
    }
};

/// Common GPU resource initialization patterns
pub const GPUResourceHelper = struct {
    /// Initialize a GPU device with standard error handling
    pub fn initDevice(window: *c.sdl.SDL_Window) ResourceError!*c.sdl.SDL_GPUDevice {
        return c.sdl.SDL_CreateGPUDevice(
            c.sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            true, // debug mode
            null // preferred backend (let SDL choose)
        ) orelse {
            const log = std.log.scoped(.resource_manager);
            log.err("Failed to create GPU device", .{});
            return ResourceError.DeviceCreationFailed;
        };
    }
    
    /// Standard window configuration for the game
    pub fn createGameWindow(title: [*:0]const u8, width: i32, height: i32) ResourceError!*c.sdl.SDL_Window {
        return c.sdl.SDL_CreateWindow(
            title,
            width,
            height,
            c.sdl.SDL_WINDOW_VULKAN
        ) orelse {
            const log = std.log.scoped(.resource_manager);
            log.err("Failed to create game window", .{});
            return ResourceError.WindowCreationFailed;
        };
    }
    
    /// Claim a window for GPU rendering
    pub fn claimWindow(device: *c.sdl.SDL_GPUDevice, window: *c.sdl.SDL_Window) ResourceError!void {
        if (!c.sdl.SDL_ClaimWindowForGPUDevice(device, window)) {
            const log = std.log.scoped(.resource_manager);
            log.err("Failed to claim window for GPU device", .{});
            return ResourceError.DeviceCreationFailed;
        }
    }
};

/// Resource lifecycle management utilities
pub const ResourceLifecycle = struct {
    /// Common initialization order for game resources
    pub fn initGameResources(
        allocator: std.mem.Allocator,
        window_title: [*:0]const u8,
        window_width: i32,
        window_height: i32
    ) ResourceError!GameResources {
        var game_resources = GameResources{
            .window = null,
            .device = null,
            .renderer_resources = null,
            .allocator = allocator,
        };
        
        // Initialize window
        game_resources.window = GPUResourceHelper.createGameWindow(window_title, window_width, window_height) catch |err| {
            game_resources.cleanup();
            return ResourceErrorHandler.logAndHandleError(err, "window creation");
        };
        
        // Initialize GPU device
        game_resources.device = GPUResourceHelper.initDevice(game_resources.window.?) catch |err| {
            game_resources.cleanup();
            return ResourceErrorHandler.logAndHandleError(err, "GPU device creation");
        };
        
        // Claim window for GPU
        GPUResourceHelper.claimWindow(game_resources.device.?, game_resources.window.?) catch |err| {
            game_resources.cleanup();
            return ResourceErrorHandler.logAndHandleError(err, "window claim");
        };
        
        // Initialize renderer resources
        var renderer_resources = allocator.create(RendererResources) catch {
            game_resources.cleanup();
            return ResourceError.OutOfMemory;
        };
        
        renderer_resources.* = initRendererResources(allocator, game_resources.window.?) catch |err| {
            allocator.destroy(renderer_resources);
            game_resources.cleanup();
            return err;
        };
        
        game_resources.renderer_resources = renderer_resources;
        
        const log = std.log.scoped(.resource_manager);
        log.info("Game resources initialized successfully", .{});
        
        return game_resources;
    }
};

/// Complete game resource bundle
pub const GameResources = struct {
    window: ?*c.sdl.SDL_Window,
    device: ?*c.sdl.SDL_GPUDevice,
    renderer_resources: ?*RendererResources,
    allocator: std.mem.Allocator,
    
    pub fn cleanup(self: *GameResources) void {
        if (self.renderer_resources) |resources| {
            resources.deinit();
            self.allocator.destroy(resources);
            self.renderer_resources = null;
        }
        
        if (self.device) |device| {
            c.sdl.SDL_DestroyGPUDevice(device);
            self.device = null;
        }
        
        if (self.window) |window| {
            c.sdl.SDL_DestroyWindow(window);
            self.window = null;
        }
    }
    
    pub fn deinit(self: *GameResources) void {
        self.cleanup();
    }
};