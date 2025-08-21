const std = @import("std");
const layout_mod = @import("../../../lib/layout/mod.zig");
const box_model = @import("../../../lib/layout/box_model.zig");
const math = @import("../../../lib/math/mod.zig");
const loggers = @import("../../../lib/debug/loggers.zig");
const sdl = @import("../../../lib/platform/sdl.zig");

const UIElement = layout_mod.UIElement;
const BoxModel = box_model.BoxModel;

/// Layout backend types with proper isolation for benchmarking
pub const LayoutBackend = union(enum) {
    cpu: CpuLayoutEngine,
    gpu: GpuLayoutEngine,

    pub fn performLayout(self: *LayoutBackend, elements: []UIElement) void {
        switch (self.*) {
            .cpu => |*cpu| cpu.performLayout(elements),
            .gpu => |*gpu| gpu.performLayout(elements),
        }
    }

    pub fn getName(self: *const LayoutBackend) []const u8 {
        return switch (self.*) {
            .cpu => "CPU",
            .gpu => "GPU (Simulated)",
        };
    }

    pub fn isRealGPU(self: *const LayoutBackend) bool {
        return switch (self.*) {
            .gpu => false, // Currently simulated, not real GPU compute
            .cpu => false,
        };
    }
};

/// CPU layout engine using real box model calculations
pub const CpuLayoutEngine = struct {
    allocator: std.mem.Allocator,
    box_models: std.ArrayList(BoxModel),

    pub fn init(allocator: std.mem.Allocator) CpuLayoutEngine {
        return .{
            .allocator = allocator,
            .box_models = std.ArrayList(BoxModel).init(allocator),
        };
    }

    pub fn deinit(self: *CpuLayoutEngine) void {
        for (self.box_models.items) |*box| {
            box.deinit(self.allocator);
        }
        self.box_models.deinit();
    }

    /// Perform CPU layout using real box model calculations
    /// NOTE: ensureBoxModels() must be called before this for allocation-free operation
    pub fn performLayout(self: *CpuLayoutEngine, elements: []UIElement) void {
        // Box models should already be pre-allocated by ensureBoxModels()
        if (self.box_models.items.len < elements.len) {
            loggers.getUILog().err("cpu_layout_insufficient_models", "Insufficient box models: have {}, need {}", .{ self.box_models.items.len, elements.len });
            return;
        }

        // Convert UIElements to BoxModels
        for (elements, 0..) |*elem, i| {
            self.uielementToBoxModel(elem, &self.box_models.items[i]);
        }

        // Perform real box model layout calculations
        for (self.box_models.items[0..elements.len], 0..) |*box, i| {
            // Handle parent-child relationships
            if (elements[i].parent_index != UIElement.INVALID_PARENT and
                elements[i].parent_index < elements.len)
            {
                const parent_box = &self.box_models.items[elements[i].parent_index];
                const parent_computed = parent_box.getLayout();

                // Position relative to parent's content area
                if (elements[i].layout_mode == @intFromEnum(UIElement.LayoutMode.relative)) {
                    const new_pos = math.Vec2{
                        .x = parent_computed.content.position.x + elements[i].position[0],
                        .y = parent_computed.content.position.y + elements[i].position[1],
                    };
                    box.setPosition(new_pos);
                }
            }

            // Force layout calculation
            _ = box.getLayout();
        }

        // Convert BoxModels back to UIElements
        for (self.box_models.items[0..elements.len], 0..) |*box, i| {
            self.boxModelToUIElement(box, &elements[i]);
        }
    }

    /// Ensure we have enough box models allocated - should be called before timing
    pub fn ensureBoxModels(self: *CpuLayoutEngine, count: usize) !void {
        while (self.box_models.items.len < count) {
            const box = try BoxModel.init(self.allocator, math.Vec2.ZERO, math.Vec2.ZERO);
            try self.box_models.append(box);
        }
    }

    /// Convert UIElement to BoxModel for real layout calculations
    fn uielementToBoxModel(self: *CpuLayoutEngine, elem: *const UIElement, box: *BoxModel) void {
        _ = self;

        // Set position and size
        box.setPosition(math.Vec2{ .x = elem.position[0], .y = elem.position[1] });
        box.setSize(math.Vec2{ .x = elem.size[0], .y = elem.size[1] });

        // Set spacing (TRBL format: top, right, bottom, left)
        box.setPaddingDetailed(elem.padding[0], elem.padding[1], elem.padding[2], elem.padding[3]);

        // Set margin per side - create a custom spacing
        const margin_spacing = BoxModel.Spacing{
            .top = elem.margin[0],
            .right = elem.margin[1],
            .bottom = elem.margin[2],
            .left = elem.margin[3],
        };
        box.margin.set(margin_spacing);
        box.markDirty();

        // Set constraints if element is dirty
        if (elem.isDirty(.constraint)) {
            // Apply basic constraints
            box.setConstraints(BoxModel.Constraints{
                .min_width = 10.0,
                .min_height = 10.0,
                .max_width = 2000.0,
                .max_height = 2000.0,
            });
        }
    }

    /// Convert BoxModel back to UIElement after layout calculations
    fn boxModelToUIElement(self: *CpuLayoutEngine, box: *BoxModel, elem: *UIElement) void {
        _ = self;

        const computed = box.getLayout();

        // Update position and size from computed layout
        elem.position[0] = computed.content.position.x;
        elem.position[1] = computed.content.position.y;
        elem.size[0] = computed.content.size.x;
        elem.size[1] = computed.content.size.y;

        // Clear dirty flags
        elem.dirty_flags = 0;
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

/// GPU backend initialization error for when GPU is unavailable
pub const GPUUnavailableError = error{GPUDeviceNotAvailable};

/// Create appropriate backend based on available hardware
pub fn createBackend(allocator: std.mem.Allocator, force_cpu: bool, gpu_device: ?*sdl.sdl.SDL_GPUDevice) !LayoutBackend {
    if (force_cpu) {
        return LayoutBackend{ .cpu = CpuLayoutEngine.init(allocator) };
    }

    if (gpu_device) |device| {
        const gpu_engine = try GpuLayoutEngine.init(allocator, device);
        return LayoutBackend{ .gpu = gpu_engine };
    } else {
        // GPU not available - return error instead of fake fallback
        return GPUUnavailableError.GPUDeviceNotAvailable;
    }
}
