/// GPU-compatible data structures for layout system
///
/// These structures must match HLSL shader definitions exactly for compute pipeline compatibility.
/// All structures are carefully aligned and sized for optimal GPU memory access patterns.

const std = @import("std");
const math = @import("../../math/mod.zig");

const Vec2 = math.Vec2;

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