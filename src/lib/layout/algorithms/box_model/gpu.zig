/// GPU implementation of CSS box model layout algorithm
const std = @import("std");
const math = @import("../../../math/mod.zig");
const core = @import("../../core/types.zig");
const interface = @import("../../core/interface.zig");
const loggers = @import("../../../debug/loggers.zig");
const sdl = @import("../../../platform/sdl.zig");

const Vec2 = math.Vec2;
const LayoutElement = interface.LayoutElement;
const LayoutResult = core.LayoutResult;
const LayoutContext = core.LayoutContext;

/// GPU-compatible UI Element structure (must match HLSL exactly)
pub const GPUElement = extern struct {
    position: [2]f32, // 8 bytes
    size: [2]f32, // 8 bytes
    padding: [4]f32, // 16 bytes - TRBL
    margin: [4]f32, // 16 bytes - TRBL
    parent_index: u32, // 4 bytes
    layout_mode: u32, // 4 bytes
    constraints: u32, // 4 bytes
    dirty_flags: u32, // 4 bytes
    // Total: 64 bytes

    pub const INVALID_PARENT = 0xFFFFFFFF;

    pub fn fromLayoutElement(element: LayoutElement) GPUElement {
        return GPUElement{
            .position = .{ element.position.x, element.position.y },
            .size = .{ element.size.x, element.size.y },
            .padding = .{ element.padding.top, element.padding.right, element.padding.bottom, element.padding.left },
            .margin = .{ element.margin.top, element.margin.right, element.margin.bottom, element.margin.left },
            .parent_index = if (element.parent_index) |p| @intCast(p) else INVALID_PARENT,
            .layout_mode = 0, // Box model = absolute positioning
            .constraints = 0, // TODO: Pack constraints into u32
            .dirty_flags = @bitCast(element.dirty_flags),
        };
    }

    pub fn toLayoutResult(self: GPUElement) LayoutResult {
        const pos = Vec2{ .x = self.position[0], .y = self.position[1] };
        const size = Vec2{ .x = self.size[0], .y = self.size[1] };

        // Calculate content area (position + padding offset, size - padding)
        const content_pos = Vec2{
            .x = pos.x + self.padding[3], // left padding
            .y = pos.y + self.padding[0], // top padding
        };
        const content_size = Vec2{
            .x = size.x - (self.padding[1] + self.padding[3]), // minus right + left
            .y = size.y - (self.padding[0] + self.padding[2]), // minus top + bottom
        };

        return LayoutResult{
            .position = pos,
            .size = size,
            .content = math.Rectangle{
                .position = content_pos,
                .size = Vec2{
                    .x = @max(0, content_size.x),
                    .y = @max(0, content_size.y),
                },
            },
            .valid = true,
        };
    }
};

/// GPU constraints structure (must match HLSL)
pub const GPUConstraint = extern struct {
    min_width: f32,
    max_width: f32,
    min_height: f32,
    max_height: f32,
    aspect_ratio: f32,
    anchor_flags: u32,
    priority: u32,
    constraint_type: u32,
    // Total: 32 bytes

    pub fn fromConstraints(constraints: core.Constraints) GPUConstraint {
        return GPUConstraint{
            .min_width = constraints.min_width,
            .max_width = constraints.max_width,
            .min_height = constraints.min_height,
            .max_height = constraints.max_height,
            .aspect_ratio = constraints.aspect_ratio orelse 0.0,
            .anchor_flags = 0,
            .priority = 0,
            .constraint_type = 0,
        };
    }
};

/// Frame data for compute shader
pub const GPUFrameData = extern struct {
    viewport_size: [2]f32,
    element_count: u32,
    pass_type: u32, // 0=measure, 1=arrange
    _padding: [2]u32,
    // Total: 32 bytes
};

/// GPU box model layout algorithm
pub const BoxModelGPU = struct {
    allocator: std.mem.Allocator,
    gpu_device: *sdl.sdl.SDL_GPUDevice,

    // GPU buffers
    element_buffer: ?*sdl.sdl.SDL_GPUBuffer = null,
    constraint_buffer: ?*sdl.sdl.SDL_GPUBuffer = null,

    // Compute pipeline
    compute_pipeline: ?*sdl.sdl.SDL_GPUComputePipeline = null,

    // Configuration
    max_elements: usize,

    pub fn init(allocator: std.mem.Allocator, gpu_device: *sdl.sdl.SDL_GPUDevice, max_elements: usize) !BoxModelGPU {
        var gpu_layout = BoxModelGPU{
            .allocator = allocator,
            .gpu_device = gpu_device,
            .max_elements = max_elements,
        };

        try gpu_layout.initializeGPU();
        return gpu_layout;
    }

    pub fn deinit(self: *BoxModelGPU) void {
        if (self.element_buffer) |buffer| {
            sdl.sdl.SDL_ReleaseGPUBuffer(self.gpu_device, buffer);
        }
        if (self.constraint_buffer) |buffer| {
            sdl.sdl.SDL_ReleaseGPUBuffer(self.gpu_device, buffer);
        }
        if (self.compute_pipeline) |pipeline| {
            sdl.sdl.SDL_ReleaseGPUComputePipeline(self.gpu_device, pipeline);
        }
    }

    fn initializeGPU(self: *BoxModelGPU) !void {
        // Create element buffer
        const element_buffer_info = sdl.sdl.SDL_GPUBufferCreateInfo{
            .usage = sdl.sdl.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE,
            .size = @sizeOf(GPUElement) * self.max_elements,
            .props = 0,
        };
        self.element_buffer = sdl.sdl.SDL_CreateGPUBuffer(self.gpu_device, &element_buffer_info);
        if (self.element_buffer == null) {
            return error.GPUBufferCreationFailed;
        }

        // Create constraint buffer
        const constraint_buffer_info = sdl.sdl.SDL_GPUBufferCreateInfo{
            .usage = sdl.sdl.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_READ,
            .size = @sizeOf(GPUConstraint) * self.max_elements,
            .props = 0,
        };
        self.constraint_buffer = sdl.sdl.SDL_CreateGPUBuffer(self.gpu_device, &constraint_buffer_info);
        if (self.constraint_buffer == null) {
            return error.GPUBufferCreationFailed;
        }

        // Load compute shader (TODO: Implement proper shader loading)
        // For now, this is a placeholder that would load the HLSL compute shader
        loggers.getRenderLog().info("gpu_box_model_init", "Box model GPU algorithm initialized", .{});
    }

    /// Calculate layout using GPU compute shader
    pub fn calculate(
        self: *BoxModelGPU,
        elements: []LayoutElement,
        context: LayoutContext,
        allocator: std.mem.Allocator,
    ) ![]LayoutResult {
        _ = self;
        _ = elements;
        _ = context;
        _ = allocator;

        // TODO: Implement SDL3 compute dispatch (see docs/hex/gpu.mdz)
        // Real implementation requires:
        // 1. SDL_CreateGPUComputePipeline() - Load compute.hlsl shader
        // 2. SDL_BeginGPUComputePass() - Start compute pass
        // 3. SDL_BindGPUComputePipeline() - Bind box model shader
        // 4. SDL_BindGPUComputeStorageBuffers() - Bind element/constraint buffers
        // 5. SDL_DispatchGPUCompute() - Execute layout calculation
        // 6. SDL_EndGPUComputePass() - Finish compute work
        
        loggers.getRenderLog().info("gpu_compute_not_implemented", 
            "GPU compute shader dispatch not yet implemented - need SDL3 pipeline integration", .{});
        
        return error.GPUComputeNotImplemented;
    }

    /// Get algorithm capabilities
    pub fn getCapabilities(self: *BoxModelGPU) interface.AlgorithmCapabilities {
        return interface.AlgorithmCapabilities{
            .name = "Box Model GPU",
            .max_elements = self.max_elements,
            .supports_gpu = true,
            .supports_incremental = false, // GPU typically recalculates all
            .complexity = .linear,
            .features = .{
                .nesting = true,
                .flexible_sizing = false,
                .content_sizing = true,
                .alignment = false,
                .wrapping = false,
                .spacing = true,
                .text_layout = false,
                .animations = false,
            },
        };
    }

    /// Check if algorithm can handle the given elements
    pub fn canHandle(self: *BoxModelGPU, elements: []const LayoutElement, context: LayoutContext) bool {
        _ = context;
        return elements.len <= self.max_elements;
    }

    /// Get algorithm name
    pub fn getName(self: *BoxModelGPU) []const u8 {
        _ = self;
        return "Box Model GPU";
    }
};

// Tests
test "GPU element conversion" {
    const testing = std.testing;

    const element = LayoutElement{
        .position = Vec2{ .x = 10, .y = 20 },
        .size = Vec2{ .x = 100, .y = 50 },
        .margin = core.Spacing{ .top = 5, .right = 10, .bottom = 15, .left = 20 },
        .padding = core.Spacing{ .top = 2, .right = 4, .bottom = 6, .left = 8 },
        .constraints = core.Constraints{},
    };

    const gpu_element = GPUElement.fromLayoutElement(element);

    try testing.expect(gpu_element.position[0] == 10);
    try testing.expect(gpu_element.position[1] == 20);
    try testing.expect(gpu_element.size[0] == 100);
    try testing.expect(gpu_element.size[1] == 50);
    try testing.expect(gpu_element.margin[0] == 5); // top
    try testing.expect(gpu_element.margin[1] == 10); // right
    try testing.expect(gpu_element.margin[2] == 15); // bottom
    try testing.expect(gpu_element.margin[3] == 20); // left
}

test "GPU element to layout result" {
    const testing = std.testing;

    const gpu_element = GPUElement{
        .position = .{ 10, 20 },
        .size = .{ 100, 50 },
        .padding = .{ 5, 5, 5, 5 }, // TRBL
        .margin = .{ 0, 0, 0, 0 },
        .parent_index = GPUElement.INVALID_PARENT,
        .layout_mode = 0,
        .constraints = 0,
        .dirty_flags = 0,
    };

    const result = gpu_element.toLayoutResult();

    try testing.expect(result.position.x == 10);
    try testing.expect(result.position.y == 20);
    try testing.expect(result.size.x == 100);
    try testing.expect(result.size.y == 50);

    // Content should be inset by padding
    try testing.expect(result.content.position.x == 15); // 10 + 5 (left padding)
    try testing.expect(result.content.position.y == 25); // 20 + 5 (top padding)
    try testing.expect(result.content.size.x == 90); // 100 - 10 (left + right padding)
    try testing.expect(result.content.size.y == 40); // 50 - 10 (top + bottom padding)
}
