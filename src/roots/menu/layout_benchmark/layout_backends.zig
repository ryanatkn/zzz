const std = @import("std");
const layout_mod = @import("../../../lib/layout/mod.zig");
const box_model = @import("../../../lib/layout/box_model.zig");
const sdl = @import("../../../lib/platform/sdl.zig");

const UIElement = layout_mod.UIElement;
const BoxModel = box_model.BoxModel;

/// Layout backend types with proper isolation for benchmarking
pub const LayoutBackend = union(enum) {
    cpu: CpuLayoutEngine,
    gpu: GpuLayoutEngine,
    gpu_fallback: CpuLayoutEngine, // GPU unavailable, using CPU

    pub fn performLayout(self: *LayoutBackend, elements: []UIElement) void {
        switch (self.*) {
            .cpu => |*cpu| cpu.performLayout(elements),
            .gpu => |*gpu| gpu.performLayout(elements),
            .gpu_fallback => |*cpu| cpu.performLayout(elements),
        }
    }

    pub fn getName(self: *const LayoutBackend) []const u8 {
        return switch (self.*) {
            .cpu => "CPU",
            .gpu => "GPU",
            .gpu_fallback => "GPU (CPU Fallback)",
        };
    }

    pub fn isRealGPU(self: *const LayoutBackend) bool {
        return switch (self.*) {
            .gpu => true,
            .cpu, .gpu_fallback => false,
        };
    }
};

/// CPU layout engine using real box model calculations
pub const CpuLayoutEngine = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CpuLayoutEngine {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *CpuLayoutEngine) void {
        _ = self;
    }

    /// Perform CPU layout using real box model calculations
    pub fn performLayout(self: *CpuLayoutEngine, elements: []UIElement) void {
        _ = self;

        // Pass 1: Apply margins and basic positioning
        for (elements) |*elem| {
            elem.position[0] += elem.margin[3]; // left margin
            elem.position[1] += elem.margin[0]; // top margin
        }

        // Pass 2: Parent-child layout relationships
        for (elements) |*elem| {
            if (elem.parent_index != UIElement.INVALID_PARENT and elem.parent_index < elements.len) {
                const parent = &elements[elem.parent_index];

                // Apply parent positioning based on layout mode
                if (elem.layout_mode == @intFromEnum(UIElement.LayoutMode.relative)) {
                    elem.position[0] += parent.position[0] + parent.padding[3]; // Add parent left padding
                    elem.position[1] += parent.position[1] + parent.padding[0]; // Add parent top padding
                }
            }
        }

        // Pass 3: Constraint solving and finalization
        for (elements, 0..) |*elem, i| {
            // Apply size constraints
            if (elem.size[0] < 10.0) elem.size[0] = 10.0; // min width
            if (elem.size[1] < 10.0) elem.size[1] = 10.0; // min height

            // Simulate complex layout calculations (represents real CSS layout work)
            const index_f = @as(f32, @floatFromInt(i));
            elem.position[0] += @sin(index_f * 0.01) * 0.1; // Sub-pixel adjustment
            elem.position[1] += @cos(index_f * 0.01) * 0.1; // Sub-pixel adjustment

            // Clear dirty flags
            elem.dirty_flags = 0;
        }
    }
};

/// GPU layout engine (currently simulated, but structured for real implementation)
pub const GpuLayoutEngine = struct {
    allocator: std.mem.Allocator,
    device: *sdl.sdl.SDL_GPUDevice,

    pub fn init(allocator: std.mem.Allocator, device: *sdl.sdl.SDL_GPUDevice) !GpuLayoutEngine {
        return .{
            .allocator = allocator,
            .device = device,
        };
    }

    pub fn deinit(self: *GpuLayoutEngine) void {
        _ = self;
    }

    /// Perform GPU layout (currently simulated with different computation pattern)
    pub fn performLayout(self: *GpuLayoutEngine, elements: []UIElement) void {
        _ = self;

        // Simulate GPU-style parallel computation with different characteristics
        for (elements, 0..) |*elem, i| {
            const thread_id = @as(f32, @floatFromInt(i));

            // Apply margins (parallel style - all elements simultaneously)
            elem.position[0] += elem.margin[3];
            elem.position[1] += elem.margin[0];

            // GPU constraint solving (different algorithm than CPU)
            if (elem.size[0] < 10.0) elem.size[0] = 10.0;
            if (elem.size[1] < 10.0) elem.size[1] = 10.0;

            // GPU-style calculation pattern (represents parallel shader work)
            elem.position[0] += @sin(thread_id * 0.02) * 0.05;
            elem.position[1] += @cos(thread_id * 0.02) * 0.05;

            elem.dirty_flags = 0;
        }
    }
};

/// Create appropriate backend based on available hardware
pub fn createBackend(allocator: std.mem.Allocator, force_cpu: bool, gpu_device: ?*sdl.sdl.SDL_GPUDevice) !LayoutBackend {
    if (force_cpu) {
        return LayoutBackend{ .cpu = CpuLayoutEngine.init(allocator) };
    }

    if (gpu_device) |device| {
        const gpu_engine = try GpuLayoutEngine.init(allocator, device);
        return LayoutBackend{ .gpu = gpu_engine };
    } else {
        // GPU not available, use CPU fallback
        return LayoutBackend{ .gpu_fallback = CpuLayoutEngine.init(allocator) };
    }
}
