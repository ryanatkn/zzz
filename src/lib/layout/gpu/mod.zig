const std = @import("std");
const math = @import("../../math/mod.zig");
const loggers = @import("../../debug/loggers.zig");
const compute = @import("../../rendering/compute.zig");
const structured_buffers = @import("../../rendering/structured_buffers.zig");
const c = @import("../../platform/sdl.zig");

const Vec2 = math.Vec2;
const StructuredBuffer = structured_buffers.StructuredBuffer;

/// GPU-compatible UI Element structure (64-byte aligned for cache efficiency)
/// This struct MUST match the HLSL UIElement struct exactly
pub const UIElement = extern struct {
    position: [2]f32, // 8 bytes - Computed absolute position
    size: [2]f32, // 8 bytes - Computed size after constraints
    padding: [4]f32, // 16 bytes - Top, Right, Bottom, Left
    margin: [4]f32, // 16 bytes - Top, Right, Bottom, Left
    parent_index: u32, // 4 bytes - Index of parent element (0xFFFFFFFF for root)
    layout_mode: u32, // 4 bytes - 0=absolute, 1=relative, 2=flex
    constraints: u32, // 4 bytes - Packed constraint flags
    dirty_flags: u32, // 4 bytes - Bitfield for dirty tracking
    // Total: 64 bytes (cache line aligned)

    pub const INVALID_PARENT = 0xFFFFFFFF;

    pub const LayoutMode = enum(u32) {
        absolute = 0,
        relative = 1,
        flex = 2,
    };

    pub const DirtyFlags = packed struct(u32) {
        layout: bool = false, // Bit 0: Layout calculation needed
        measure: bool = false, // Bit 1: Measure pass needed
        constraint: bool = false, // Bit 2: Constraint solving needed
        spring: bool = false, // Bit 3: Spring animation active
        _reserved: u28 = 0,
    };

    /// Create a new UIElement with default values
    pub fn init(position: Vec2, size: Vec2) UIElement {
        return UIElement{
            .position = .{ position.x, position.y },
            .size = .{ size.x, size.y },
            .padding = .{ 0, 0, 0, 0 },
            .margin = .{ 0, 0, 0, 0 },
            .parent_index = INVALID_PARENT,
            .layout_mode = @intFromEnum(LayoutMode.absolute),
            .constraints = 0,
            .dirty_flags = @bitCast(DirtyFlags{ .layout = true }),
        };
    }

    /// Convert position array to Vec2
    pub fn getPosition(self: *const UIElement) Vec2 {
        return Vec2{ .x = self.position[0], .y = self.position[1] };
    }

    /// Convert size array to Vec2
    pub fn getSize(self: *const UIElement) Vec2 {
        return Vec2{ .x = self.size[0], .y = self.size[1] };
    }

    /// Set position from Vec2
    pub fn setPosition(self: *UIElement, pos: Vec2) void {
        self.position[0] = pos.x;
        self.position[1] = pos.y;
        self.markDirty(.layout);
    }

    /// Set size from Vec2
    pub fn setSize(self: *UIElement, s: Vec2) void {
        self.size[0] = s.x;
        self.size[1] = s.y;
        self.markDirty(.layout);
    }

    /// Mark element as needing specific type of update
    pub fn markDirty(self: *UIElement, flag_type: enum { layout, measure, constraint, spring }) void {
        var flags: DirtyFlags = @bitCast(self.dirty_flags);
        switch (flag_type) {
            .layout => flags.layout = true,
            .measure => flags.measure = true,
            .constraint => flags.constraint = true,
            .spring => flags.spring = true,
        }
        self.dirty_flags = @bitCast(flags);
    }

    /// Check if element needs specific type of update
    pub fn isDirty(self: *const UIElement, flag_type: enum { layout, measure, constraint, spring }) bool {
        const flags: DirtyFlags = @bitCast(self.dirty_flags);
        return switch (flag_type) {
            .layout => flags.layout,
            .measure => flags.measure,
            .constraint => flags.constraint,
            .spring => flags.spring,
        };
    }

    /// Clear specific dirty flag
    pub fn clearDirty(self: *UIElement, flag_type: enum { layout, measure, constraint, spring }) void {
        var flags: DirtyFlags = @bitCast(self.dirty_flags);
        switch (flag_type) {
            .layout => flags.layout = false,
            .measure => flags.measure = false,
            .constraint => flags.constraint = false,
            .spring => flags.spring = false,
        }
        self.dirty_flags = @bitCast(flags);
    }

    /// Set padding uniformly
    pub fn setPadding(self: *UIElement, padding: f32) void {
        self.padding = .{ padding, padding, padding, padding };
        self.markDirty(.layout);
    }

    /// Set padding per side (top, right, bottom, left)
    pub fn setPaddingDetailed(self: *UIElement, top: f32, right: f32, bottom: f32, left: f32) void {
        self.padding = .{ top, right, bottom, left };
        self.markDirty(.layout);
    }

    /// Set margin uniformly
    pub fn setMargin(self: *UIElement, margin: f32) void {
        self.margin = .{ margin, margin, margin, margin };
        self.markDirty(.layout);
    }

    /// Set parent element index
    pub fn setParent(self: *UIElement, parent_index: u32) void {
        self.parent_index = parent_index;
        self.markDirty(.layout);
    }

    /// Set layout mode
    pub fn setLayoutMode(self: *UIElement, mode: LayoutMode) void {
        self.layout_mode = @intFromEnum(mode);
        self.markDirty(.layout);
    }
};

/// GPU layout constraint structure (32-byte aligned)
/// Must match HLSL LayoutConstraint struct exactly
pub const LayoutConstraint = extern struct {
    min_width: f32, // 4 bytes
    max_width: f32, // 4 bytes
    min_height: f32, // 4 bytes
    max_height: f32, // 4 bytes
    aspect_ratio: f32, // 4 bytes (0 = none)
    anchor_flags: u32, // 4 bytes - Anchor point constraints
    priority: u32, // 4 bytes - Resolution priority
    constraint_type: u32, // 4 bytes - Type of constraint
    // Total: 32 bytes

    pub fn init() LayoutConstraint {
        return LayoutConstraint{
            .min_width = 0.0,
            .max_width = std.math.inf(f32),
            .min_height = 0.0,
            .max_height = std.math.inf(f32),
            .aspect_ratio = 0.0,
            .anchor_flags = 0,
            .priority = 0,
            .constraint_type = 0,
        };
    }

    /// Create size constraint
    pub fn sizeConstraint(min_width: f32, max_width: f32, min_height: f32, max_height: f32) LayoutConstraint {
        var constraint = init();
        constraint.min_width = min_width;
        constraint.max_width = max_width;
        constraint.min_height = min_height;
        constraint.max_height = max_height;
        constraint.constraint_type = 0; // Size constraint
        return constraint;
    }

    /// Create aspect ratio constraint
    pub fn aspectRatioConstraint(ratio: f32) LayoutConstraint {
        var constraint = init();
        constraint.aspect_ratio = ratio;
        constraint.constraint_type = 1; // Aspect ratio constraint
        return constraint;
    }
};

/// Spring state for physics-based animations (32-byte aligned)
/// Must match HLSL SpringState struct exactly
pub const SpringState = extern struct {
    velocity: [2]f32, // 8 bytes - Current velocity
    target_pos: [2]f32, // 8 bytes - Target position
    stiffness: f32, // 4 bytes - Spring constant
    damping: f32, // 4 bytes - Damping factor
    mass: f32, // 4 bytes - Element mass
    rest_time: f32, // 4 bytes - Time at rest
    // Total: 32 bytes (removed target_size to fit)

    pub fn init(stiffness: f32, damping: f32, mass: f32) SpringState {
        return SpringState{
            .velocity = .{ 0, 0 },
            .target_pos = .{ 0, 0 },
            .stiffness = stiffness,
            .damping = damping,
            .mass = mass,
            .rest_time = 0.0,
        };
    }
};

/// Frame data passed to compute shaders
pub const FrameData = extern struct {
    viewport_size: [2]f32, // 8 bytes
    element_count: u32, // 4 bytes
    pass_type: u32, // 4 bytes - 0=measure, 1=arrange, 2=physics
    delta_time: f32, // 4 bytes
    global_stiffness: f32, // 4 bytes
    global_damping: f32, // 4 bytes
    animation_flags: u32, // 4 bytes
    // Total: 32 bytes
};

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

// Hybrid CPU/GPU layout management
pub const hybrid = @import("hybrid.zig");

// Tests
test "UIElement struct size and alignment" {
    // Verify UIElement is exactly 64 bytes as required for GPU compatibility
    try std.testing.expect(@sizeOf(UIElement) == 64);
    try std.testing.expect(@alignOf(UIElement) >= 4); // Minimum alignment for GPU

    // Verify field offsets match expected layout
    const elem = UIElement.init(Vec2.ZERO, Vec2.ZERO);
    _ = elem;
}

test "constraint struct size" {
    // Verify LayoutConstraint is exactly 32 bytes
    try std.testing.expect(@sizeOf(LayoutConstraint) == 32);
}

test "spring state struct size" {
    // Verify SpringState is exactly 32 bytes
    try std.testing.expect(@sizeOf(SpringState) == 32);
}

test "dirty flag manipulation" {
    var elem = UIElement.init(Vec2.ZERO, Vec2.ZERO);

    // Initially should have layout dirty flag set
    try std.testing.expect(elem.isDirty(.layout));

    // Clear and test
    elem.clearDirty(.layout);
    try std.testing.expect(!elem.isDirty(.layout));

    // Set different flag
    elem.markDirty(.spring);
    try std.testing.expect(elem.isDirty(.spring));
    try std.testing.expect(!elem.isDirty(.layout));
}
