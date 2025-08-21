/// GPU-accelerated layout engine implementation
///
/// This module provides a complete GPU-based layout system using compute shaders
/// for high-performance layout calculation on large numbers of UI elements.
const std = @import("std");
const math = @import("../../math/mod.zig");
const loggers = @import("../../debug/loggers.zig");
const compute = @import("../../rendering/compute.zig");
const structured_buffers = @import("../../rendering/structured_buffers.zig");
const c = @import("../../platform/sdl.zig");
const structures = @import("structures.zig");

const Vec2 = math.Vec2;
const StructuredBuffer = structured_buffers.StructuredBuffer;
const UIElement = structures.UIElement;
const LayoutConstraint = structures.LayoutConstraint;
const SpringState = structures.SpringState;
const FrameData = structures.FrameData;

/// Main GPU layout engine
pub const GPULayoutEngine = struct {
    allocator: std.mem.Allocator,
    device: *c.sdl.SDL_GPUDevice,

    // Compute infrastructure
    dispatcher: compute.ComputeDispatcher,
    box_model_pipeline: ?*compute.ComputePipeline,
    constraint_pipeline: ?*compute.ComputePipeline,
    spring_pipeline: ?*compute.ComputePipeline,

    // GPU buffers
    element_buffer: StructuredBuffer(UIElement),
    constraint_buffer: StructuredBuffer(LayoutConstraint),
    spring_buffer: StructuredBuffer(SpringState),

    // Layout state
    element_capacity: usize,
    viewport_size: Vec2,
    frame_data: FrameData,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, device: *c.sdl.SDL_GPUDevice, element_capacity: usize) !Self {
        loggers.getRenderLog().info("gpu_layout_init", "Initializing GPU layout engine with capacity: {}", .{element_capacity});

        // Create compute dispatcher
        const dispatcher = compute.ComputeDispatcher.init(allocator, device);

        // Create structured buffers
        const element_buffer_info = StructuredBuffer(UIElement).CreateInfo{
            .capacity = element_capacity,
            .usage = c.sdl.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE,
            .name = "UIElement Buffer",
            .enable_transfer = true,
        };

        const constraint_buffer_info = StructuredBuffer(LayoutConstraint).CreateInfo{
            .capacity = element_capacity,
            .usage = c.sdl.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_READ,
            .name = "Constraint Buffer",
            .enable_transfer = true,
        };

        const spring_buffer_info = StructuredBuffer(SpringState).CreateInfo{
            .capacity = element_capacity,
            .usage = c.sdl.SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE,
            .name = "Spring Buffer",
            .enable_transfer = true,
        };

        var engine = Self{
            .allocator = allocator,
            .device = device,
            .dispatcher = dispatcher,
            .box_model_pipeline = null,
            .constraint_pipeline = null,
            .spring_pipeline = null,
            .element_buffer = try StructuredBuffer(UIElement).init(allocator, device, element_buffer_info),
            .constraint_buffer = try StructuredBuffer(LayoutConstraint).init(allocator, device, constraint_buffer_info),
            .spring_buffer = try StructuredBuffer(SpringState).init(allocator, device, spring_buffer_info),
            .element_capacity = element_capacity,
            .viewport_size = Vec2{ .x = 800, .y = 600 }, // Default viewport
            .frame_data = FrameData{
                .viewport_size = .{ 800, 600 },
                .element_count = 0,
                .pass_type = 0,
                .delta_time = 0.016, // 60 FPS default
                .global_stiffness = 1.0,
                .global_damping = 1.0,
                .animation_flags = 0,
            },
        };

        // Load compute pipelines
        try engine.loadComputePipelines();

        loggers.getRenderLog().info("gpu_layout_ready", "GPU layout engine initialized successfully", .{});
        return engine;
    }

    pub fn deinit(self: *Self) void {
        self.element_buffer.deinit();
        self.constraint_buffer.deinit();
        self.spring_buffer.deinit();
        self.dispatcher.deinit();
        loggers.getRenderLog().info("gpu_layout_cleanup", "GPU layout engine cleaned up", .{});
    }

    fn loadComputePipelines(self: *Self) !void {
        // Load box model compute pipeline
        self.box_model_pipeline = try self.dispatcher.loadComputePipeline("layout_box_model", 1, // num_storage_buffers (UIElement buffer)
            0, // num_storage_textures
            1 // num_uniform_buffers (FrameData)
        );

        // Load constraint solver pipeline
        self.constraint_pipeline = try self.dispatcher.loadComputePipeline("layout_constraints", 1, // num_storage_buffers (UIElement buffer)
            1, // num_storage_textures (Constraint buffer - readonly)
            1 // num_uniform_buffers (FrameData)
        );

        // Load spring physics pipeline
        self.spring_pipeline = try self.dispatcher.loadComputePipeline("layout_spring_physics", 2, // num_storage_buffers (UIElement + SpringState buffers)
            0, // num_storage_textures
            1 // num_uniform_buffers (FrameData)
        );

        loggers.getRenderLog().info("compute_pipelines_loaded", "All layout compute pipelines loaded successfully", .{});
    }

    /// Update viewport size
    pub fn setViewportSize(self: *Self, viewport_size: Vec2) void {
        self.viewport_size = viewport_size;
        self.frame_data.viewport_size = .{ viewport_size.x, viewport_size.y };
    }

    /// Upload element data to GPU
    pub fn uploadElements(self: *Self, elements: []const UIElement) !void {
        if (elements.len > self.element_capacity) {
            return error.TooManyElements;
        }

        try self.element_buffer.upload(elements);
        self.frame_data.element_count = @intCast(elements.len);

        loggers.getRenderLog().info("elements_uploaded", "Uploaded {} elements to GPU", .{elements.len});
    }

    /// Upload constraint data to GPU
    pub fn uploadConstraints(self: *Self, constraints: []const LayoutConstraint) !void {
        try self.constraint_buffer.upload(constraints);
        loggers.getRenderLog().info("constraints_uploaded", "Uploaded {} constraints to GPU", .{constraints.len});
    }

    /// Upload spring state data to GPU
    pub fn uploadSprings(self: *Self, springs: []const SpringState) !void {
        try self.spring_buffer.upload(springs);
        loggers.getRenderLog().info("springs_uploaded", "Uploaded {} spring states to GPU", .{springs.len});
    }

    /// Perform GPU layout calculation
    pub fn performLayout(self: *Self, command_buffer: *c.sdl.SDL_GPUCommandBuffer, delta_time: f32) !void {
        if (self.frame_data.element_count == 0) return;

        self.frame_data.delta_time = delta_time;

        // Create storage buffer array for compute pass
        const storage_buffers = [_]*c.sdl.SDL_GPUBuffer{
            self.element_buffer.getBuffer(),
            self.spring_buffer.getBuffer(),
        };

        // Begin compute pass
        var compute_pass = try compute.ComputePass.begin(command_buffer, &storage_buffers, null);
        defer compute_pass.deinit();

        const dispatch_groups = compute.calculateDispatchGroups(self.frame_data.element_count, 64);

        // Pass 1: Box model layout calculation
        if (self.box_model_pipeline) |pipeline| {
            compute_pass.bindPipeline(pipeline);

            self.frame_data.pass_type = 1; // Arrange pass
            const frame_data_bytes = std.mem.asBytes(&self.frame_data);
            compute_pass.pushUniformData(0, frame_data_bytes);

            compute_pass.dispatch(dispatch_groups, 1, 1);

            loggers.getRenderLog().info("gpu_layout_dispatch", "Dispatched box model layout: {} groups", .{dispatch_groups});
        }

        // Pass 2: Constraint solving (if enabled)
        if (self.constraint_pipeline) |pipeline| {
            compute_pass.bindPipeline(pipeline);

            self.frame_data.pass_type = 2; // Constraint pass
            const frame_data_bytes = std.mem.asBytes(&self.frame_data);
            compute_pass.pushUniformData(0, frame_data_bytes);

            compute_pass.dispatch(dispatch_groups, 1, 1);

            loggers.getRenderLog().info("gpu_constraint_dispatch", "Dispatched constraint solving: {} groups", .{dispatch_groups});
        }

        // Pass 3: Spring physics (if enabled)
        if (self.spring_pipeline) |pipeline| {
            compute_pass.bindPipeline(pipeline);

            self.frame_data.pass_type = 3; // Physics pass
            const frame_data_bytes = std.mem.asBytes(&self.frame_data);
            compute_pass.pushUniformData(0, frame_data_bytes);

            compute_pass.dispatch(dispatch_groups, 1, 1);

            loggers.getRenderLog().info("gpu_spring_dispatch", "Dispatched spring physics: {} groups", .{dispatch_groups});
        }

        compute_pass.end();
    }

    /// Download layout results from GPU (expensive - use sparingly)
    pub fn downloadElements(self: *Self, command_buffer: *c.sdl.SDL_GPUCommandBuffer) ![]UIElement {
        const elements = try self.element_buffer.download(self.allocator, command_buffer);
        loggers.getRenderLog().info("elements_downloaded", "Downloaded {} elements from GPU", .{elements.len});
        return elements;
    }

    /// Get element buffer for direct GPU-GPU rendering
    pub fn getElementBuffer(self: *Self) *c.sdl.SDL_GPUBuffer {
        return self.element_buffer.getBuffer();
    }

    /// Get current element count
    pub fn getElementCount(self: *Self) u32 {
        return self.frame_data.element_count;
    }
};
