/// Stacking context and z-index management for layout arrangement
///
/// This module provides utilities for managing layered elements,
/// stacking contexts, and z-index ordering in layout systems.
const std = @import("std");
const math = @import("../../math/mod.zig");
const types = @import("../types.zig");

const Vec2 = math.Vec2;
const Rectangle = math.Rectangle;
const LayoutResult = types.LayoutResult;

/// Z-index value for stacking order
pub const ZIndex = i32;

/// Special z-index values
pub const AUTO_Z_INDEX: ZIndex = 0;
pub const NEGATIVE_Z_INDEX: ZIndex = -1;
pub const POSITIVE_Z_INDEX: ZIndex = 1;

/// Stacking context types
pub const StackingContextType = enum {
    root, // Root stacking context
    positioned, // Positioned element with z-index
    opacity, // Element with opacity < 1.0
    transform, // Element with transform
    filter, // Element with filter effects
    isolation, // Element with isolation: isolate
    will_change, // Element with will-change
};

/// Element stacking information
pub const StackingInfo = struct {
    z_index: ZIndex = AUTO_Z_INDEX,
    context_type: StackingContextType = .root,
    opacity: f32 = 1.0,
    creates_context: bool = false, // Whether this element creates a new stacking context
    parent_context_id: ?usize = null, // ID of parent stacking context
    element_index: usize = 0,
};

/// Stacking context for managing layered rendering
pub const StackingContext = struct {
    id: usize,
    z_index: ZIndex,
    context_type: StackingContextType,
    elements: std.ArrayList(usize), // Element indices in this context
    children: std.ArrayList(usize), // Child context IDs
    parent_id: ?usize,

    pub fn init(allocator: std.mem.Allocator, id: usize, z_index: ZIndex, context_type: StackingContextType, parent_id: ?usize) StackingContext {
        return StackingContext{
            .id = id,
            .z_index = z_index,
            .context_type = context_type,
            .elements = std.ArrayList(usize).init(allocator),
            .children = std.ArrayList(usize).init(allocator),
            .parent_id = parent_id,
        };
    }

    pub fn deinit(self: *StackingContext) void {
        self.elements.deinit();
        self.children.deinit();
    }
};

/// Stacking order manager
pub const StackingManager = struct {
    allocator: std.mem.Allocator,
    contexts: std.ArrayList(StackingContext),
    root_context_id: usize,
    next_context_id: usize,

    pub fn init(allocator: std.mem.Allocator) StackingManager {
        var manager = StackingManager{
            .allocator = allocator,
            .contexts = std.ArrayList(StackingContext).init(allocator),
            .root_context_id = 0,
            .next_context_id = 1,
        };

        // Create root stacking context
        const root_context = StackingContext.init(allocator, 0, 0, .root, null);
        manager.contexts.append(root_context) catch unreachable;

        return manager;
    }

    pub fn deinit(self: *StackingManager) void {
        for (self.contexts.items) |*context| {
            context.deinit();
        }
        self.contexts.deinit();
    }

    /// Build stacking contexts from element information
    pub fn buildStackingContexts(self: *StackingManager, stacking_infos: []const StackingInfo) !void {
        // Clear existing contexts except root
        for (self.contexts.items[1..]) |*context| {
            context.deinit();
        }
        self.contexts.shrinkRetainingCapacity(1);
        self.contexts.items[0].elements.clearRetainingCapacity();
        self.contexts.items[0].children.clearRetainingCapacity();
        self.next_context_id = 1;

        // Process each element
        for (stacking_infos, 0..) |info, element_index| {
            if (info.creates_context) {
                // Create new stacking context
                const context_id = self.next_context_id;
                self.next_context_id += 1;

                const parent_id = info.parent_context_id orelse self.root_context_id;
                var new_context = StackingContext.init(
                    self.allocator,
                    context_id,
                    info.z_index,
                    info.context_type,
                    parent_id,
                );

                try new_context.elements.append(element_index);
                try self.contexts.append(new_context);

                // Add to parent's children list
                for (self.contexts.items) |*context| {
                    if (context.id == parent_id) {
                        try context.children.append(context_id);
                        break;
                    }
                }
            } else {
                // Add to appropriate existing context
                const context_id = info.parent_context_id orelse self.root_context_id;
                for (self.contexts.items) |*context| {
                    if (context.id == context_id) {
                        try context.elements.append(element_index);
                        break;
                    }
                }
            }
        }
    }

    /// Get rendering order for all elements
    pub fn getRenderingOrder(self: *StackingManager, allocator: std.mem.Allocator) ![]usize {
        var order = std.ArrayList(usize).init(allocator);
        try self.collectRenderingOrder(self.root_context_id, &order);
        return order.toOwnedSlice();
    }

    /// Recursively collect rendering order from a context
    fn collectRenderingOrder(self: *StackingManager, context_id: usize, order: *std.ArrayList(usize)) !void {
        const context = self.getContext(context_id) orelse return;

        // Sort child contexts by z-index
        const child_contexts = try self.allocator.alloc(usize, context.children.items.len);
        defer self.allocator.free(child_contexts);
        @memcpy(child_contexts, context.children.items);

        std.sort.pdq(usize, child_contexts, self, compareContextZIndex);

        // Collect elements and children in stacking order
        // 1. Negative z-index children
        for (child_contexts) |child_id| {
            const child_context = self.getContext(child_id) orelse continue;
            if (child_context.z_index < 0) {
                try self.collectRenderingOrder(child_id, order);
            }
        }

        // 2. Elements in current context (z-index 0 and auto)
        try order.appendSlice(context.elements.items);

        // 3. Positive z-index children
        for (child_contexts) |child_id| {
            const child_context = self.getContext(child_id) orelse continue;
            if (child_context.z_index > 0) {
                try self.collectRenderingOrder(child_id, order);
            }
        }
    }

    fn getContext(self: *StackingManager, context_id: usize) ?*StackingContext {
        for (self.contexts.items) |*context| {
            if (context.id == context_id) {
                return context;
            }
        }
        return null;
    }

    fn compareContextZIndex(self: *StackingManager, a_id: usize, b_id: usize) bool {
        const a_context = self.getContext(a_id) orelse return false;
        const b_context = self.getContext(b_id) orelse return true;

        if (a_context.z_index != b_context.z_index) {
            return a_context.z_index < b_context.z_index;
        }

        // Same z-index, order by context creation order
        return a_context.id < b_context.id;
    }
};

/// Z-index sorting utilities
pub const ZIndexSorting = struct {
    /// Element with z-index information
    pub const ZElement = struct {
        element_index: usize,
        z_index: ZIndex,
        stacking_context_id: usize,
        document_order: usize, // For tie-breaking
    };

    /// Sort elements by z-index within the same stacking context
    pub fn sortByZIndex(elements: []ZElement) void {
        std.sort.pdq(ZElement, elements, {}, compareZElements);
    }

    fn compareZElements(_: void, a: ZElement, b: ZElement) bool {
        // Different stacking contexts - shouldn't be compared here
        if (a.stacking_context_id != b.stacking_context_id) {
            return a.stacking_context_id < b.stacking_context_id;
        }

        // Same context - compare z-index
        if (a.z_index != b.z_index) {
            return a.z_index < b.z_index;
        }

        // Same z-index - use document order
        return a.document_order < b.document_order;
    }

    /// Create z-elements from layout results and stacking info
    pub fn createZElements(
        results: []const LayoutResult,
        stacking_infos: []const StackingInfo,
        allocator: std.mem.Allocator,
    ) ![]ZElement {
        if (results.len != stacking_infos.len) {
            return error.MismatchedArrayLengths;
        }

        var z_elements = try allocator.alloc(ZElement, results.len);

        for (results, stacking_infos, 0..) |result, info, i| {
            z_elements[i] = ZElement{
                .element_index = result.element_index,
                .z_index = info.z_index,
                .stacking_context_id = info.parent_context_id orelse 0,
                .document_order = i,
            };
        }

        return z_elements;
    }
};

/// Layer management for rendering optimization
pub const LayerManager = struct {
    /// Rendering layer information
    pub const Layer = struct {
        id: usize,
        z_range: struct { min: ZIndex, max: ZIndex },
        elements: std.ArrayList(usize),
        needs_repaint: bool = false,
        opacity: f32 = 1.0,

        pub fn init(allocator: std.mem.Allocator, id: usize, min_z: ZIndex, max_z: ZIndex) Layer {
            return Layer{
                .id = id,
                .z_range = .{ .min = min_z, .max = max_z },
                .elements = std.ArrayList(usize).init(allocator),
            };
        }

        pub fn deinit(self: *Layer) void {
            self.elements.deinit();
        }

        pub fn containsZIndex(self: *const Layer, z_index: ZIndex) bool {
            return z_index >= self.z_range.min and z_index <= self.z_range.max;
        }
    };

    allocator: std.mem.Allocator,
    layers: std.ArrayList(Layer),
    next_layer_id: usize,

    pub fn init(allocator: std.mem.Allocator) LayerManager {
        return LayerManager{
            .allocator = allocator,
            .layers = std.ArrayList(Layer).init(allocator),
            .next_layer_id = 0,
        };
    }

    pub fn deinit(self: *LayerManager) void {
        for (self.layers.items) |*layer| {
            layer.deinit();
        }
        self.layers.deinit();
    }

    /// Create layers based on z-index ranges
    pub fn createLayers(self: *LayerManager, z_elements: []const ZIndexSorting.ZElement) !void {
        // Clear existing layers
        for (self.layers.items) |*layer| {
            layer.deinit();
        }
        self.layers.clearRetainingCapacity();

        if (z_elements.len == 0) return;

        // Group elements by z-index ranges
        var current_z = z_elements[0].z_index;
        var layer_start: usize = 0;

        for (z_elements, 0..) |z_element, i| {
            // Create new layer when z-index changes significantly
            if (z_element.z_index != current_z or i == z_elements.len - 1) {
                const layer_end = if (z_element.z_index != current_z) i else i + 1;

                var layer = Layer.init(self.allocator, self.next_layer_id, current_z, current_z);
                self.next_layer_id += 1;

                // Add elements to layer
                for (z_elements[layer_start..layer_end]) |element| {
                    try layer.elements.append(element.element_index);
                }

                try self.layers.append(layer);

                current_z = z_element.z_index;
                layer_start = i;
            }
        }
    }

    /// Mark layers that need repainting
    pub fn markDirty(self: *LayerManager, element_indices: []const usize) void {
        for (self.layers.items) |*layer| {
            for (element_indices) |element_index| {
                for (layer.elements.items) |layer_element| {
                    if (layer_element == element_index) {
                        layer.needs_repaint = true;
                        break;
                    }
                }
            }
        }
    }

    /// Get layers that need repainting
    pub fn getDirtyLayers(self: *LayerManager, allocator: std.mem.Allocator) ![]usize {
        var dirty_layers = std.ArrayList(usize).init(allocator);

        for (self.layers.items) |layer| {
            if (layer.needs_repaint) {
                try dirty_layers.append(layer.id);
            }
        }

        return dirty_layers.toOwnedSlice();
    }

    /// Clear dirty flags
    pub fn clearDirtyFlags(self: *LayerManager) void {
        for (self.layers.items) |*layer| {
            layer.needs_repaint = false;
        }
    }
};

// Tests
test "z-index sorting" {
    const testing = std.testing;

    var elements = [_]ZIndexSorting.ZElement{
        ZIndexSorting.ZElement{ .element_index = 0, .z_index = 10, .stacking_context_id = 0, .document_order = 0 },
        ZIndexSorting.ZElement{ .element_index = 1, .z_index = -5, .stacking_context_id = 0, .document_order = 1 },
        ZIndexSorting.ZElement{ .element_index = 2, .z_index = 0, .stacking_context_id = 0, .document_order = 2 },
        ZIndexSorting.ZElement{ .element_index = 3, .z_index = 10, .stacking_context_id = 0, .document_order = 3 },
    };

    ZIndexSorting.sortByZIndex(&elements);

    // Should be sorted: -5, 0, 10, 10 (with document order for ties)
    try testing.expect(elements[0].z_index == -5);
    try testing.expect(elements[1].z_index == 0);
    try testing.expect(elements[2].z_index == 10 and elements[2].document_order == 0);
    try testing.expect(elements[3].z_index == 10 and elements[3].document_order == 3);
}

test "stacking context management" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var manager = StackingManager.init(allocator);
    defer manager.deinit();

    const stacking_infos = [_]StackingInfo{
        StackingInfo{ .z_index = 0, .creates_context = false, .element_index = 0 },
        StackingInfo{ .z_index = 10, .creates_context = true, .element_index = 1 },
        StackingInfo{ .z_index = -5, .creates_context = true, .element_index = 2 },
    };

    try manager.buildStackingContexts(&stacking_infos);

    const render_order = try manager.getRenderingOrder(allocator);
    defer allocator.free(render_order);

    // Should render negative z-index first, then root elements, then positive z-index
    try testing.expect(render_order.len >= 3);
    // Exact order depends on implementation, but negative z-index should come first
    var has_negative_first = false;
    for (render_order) |element_index| {
        if (element_index == 2) { // Element with z-index -5
            has_negative_first = true;
            break;
        }
        if (element_index == 1) { // Element with z-index 10
            break; // Positive came before negative - wrong order
        }
    }
    try testing.expect(has_negative_first);
}

test "layer management" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var layer_manager = LayerManager.init(allocator);
    defer layer_manager.deinit();

    const z_elements = [_]ZIndexSorting.ZElement{
        ZIndexSorting.ZElement{ .element_index = 0, .z_index = 0, .stacking_context_id = 0, .document_order = 0 },
        ZIndexSorting.ZElement{ .element_index = 1, .z_index = 0, .stacking_context_id = 0, .document_order = 1 },
        ZIndexSorting.ZElement{ .element_index = 2, .z_index = 10, .stacking_context_id = 0, .document_order = 2 },
    };

    try layer_manager.createLayers(&z_elements);

    try testing.expect(layer_manager.layers.items.len >= 1);

    // Mark some elements as dirty
    const dirty_elements = [_]usize{ 0, 2 };
    layer_manager.markDirty(&dirty_elements);

    const dirty_layers = try layer_manager.getDirtyLayers(allocator);
    defer allocator.free(dirty_layers);

    try testing.expect(dirty_layers.len > 0);
}
