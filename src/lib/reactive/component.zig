const std = @import("std");
const signal = @import("signal.zig");
const computed = @import("computed.zig");
const effect = @import("effect.zig");
const context = @import("context.zig");
const batch = @import("batch.zig");

/// Base reactive component for UI elements
/// Provides automatic re-rendering when reactive dependencies change
pub const ReactiveComponent = struct {
    allocator: std.mem.Allocator,
    
    // Core reactive state
    is_mounted: *signal.Signal(bool),
    needs_render: *signal.Signal(bool),
    
    // Lifecycle effects
    mount_effect: ?*effect.Effect,
    render_effect: ?*effect.Effect,
    
    // Component state (type-erased pointer to actual component data)
    component_state: *anyopaque,
    component_vtable: *const ComponentVTable,
    
    // Render tracking
    last_render_time: u64,
    
    const Self = @This();
    
    pub const ComponentVTable = struct {
        /// Called when component is mounted
        onMount: *const fn (component_state: *anyopaque) anyerror!void,
        
        /// Called when component is unmounted
        onUnmount: *const fn (component_state: *anyopaque) void,
        
        /// Called when component needs to re-render (reactive dependencies changed)
        onRender: *const fn (component_state: *anyopaque) anyerror!void,
        
        /// Called to check if component should render (optimization)
        shouldRender: ?*const fn (component_state: *anyopaque) bool = null,
        
        /// Cleanup component-specific resources
        destroy: *const fn (component_state: *anyopaque, allocator: std.mem.Allocator) void,
    };
    
    pub fn init(
        allocator: std.mem.Allocator,
        component_state: *anyopaque,
        vtable: *const ComponentVTable
    ) !Self {
        // Create signal instances
        const is_mounted_signal = try allocator.create(signal.Signal(bool));
        is_mounted_signal.* = try signal.Signal(bool).init(allocator, false);
        
        const needs_render_signal = try allocator.create(signal.Signal(bool));
        needs_render_signal.* = try signal.Signal(bool).init(allocator, true);
        
        return Self{
            .allocator = allocator,
            .is_mounted = is_mounted_signal,
            .needs_render = needs_render_signal,
            .mount_effect = null,
            .render_effect = null,
            .component_state = component_state,
            .component_vtable = vtable,
            .last_render_time = 0,
        };
    }
    
    pub fn mount(self: *Self) !void {
        if (self.is_mounted.peek()) return; // Already mounted
        
        // Set up mount effect to call onMount when mounted
        const SelfRef = struct {
            var component_ref: *ReactiveComponent = undefined;
        };
        SelfRef.component_ref = self;
        
        self.mount_effect = try effect.createEffect(self.allocator, struct {
            fn run() void {
                const comp = SelfRef.component_ref;
                const is_mounted = comp.is_mounted.get();
                
                if (is_mounted) {
                    comp.component_vtable.onMount(comp.component_state) catch |err| {
                        std.debug.print("Component onMount error: {}\n", .{err});
                    };
                }
            }
        }.run);
        
        // Set up render effect for automatic re-rendering
        self.render_effect = try effect.createEffect(self.allocator, struct {
            fn run() void {
                const comp = SelfRef.component_ref;
                const is_mounted = comp.is_mounted.get();
                const needs_render = comp.needs_render.get();
                
                if (is_mounted and needs_render) {
                    // Check if should render (optimization hook)
                    const should_render = if (comp.component_vtable.shouldRender) |shouldRenderFn|
                        shouldRenderFn(comp.component_state)
                    else
                        true;
                    
                    if (should_render) {
                        comp.component_vtable.onRender(comp.component_state) catch |err| {
                            std.debug.print("Component onRender error: {}\n", .{err});
                        };
                        
                        // Update render time
                        comp.last_render_time = @as(u64, @intCast(std.time.milliTimestamp()));
                        
                        // Reset needs_render flag
                        comp.needs_render.set(false);
                    }
                }
            }
        }.run);
        
        // Activate component
        self.is_mounted.set(true);
    }
    
    pub fn unmount(self: *Self) void {
        if (!self.is_mounted.peek()) return; // Already unmounted
        
        // Call component unmount
        self.component_vtable.onUnmount(self.component_state);
        
        // Clean up effects
        if (self.mount_effect) |eff| {
            eff.cleanup();
            self.allocator.destroy(eff);
            self.mount_effect = null;
        }
        
        if (self.render_effect) |eff| {
            eff.cleanup();
            self.allocator.destroy(eff);
            self.render_effect = null;
        }
        
        // Mark as unmounted
        self.is_mounted.set(false);
    }
    
    /// Manually trigger a re-render
    pub fn requestRender(self: *Self) void {
        self.needs_render.set(true);
    }
    
    /// Check if component is currently mounted
    pub fn isMounted(self: *const Self) bool {
        return self.is_mounted.peek();
    }
    
    /// Check if component needs rendering
    pub fn needsRender(self: *const Self) bool {
        return self.needs_render.peek();
    }
    
    /// Get last render time in milliseconds
    pub fn getLastRenderTime(self: *const Self) u64 {
        return self.last_render_time;
    }
    
    pub fn deinit(self: *Self) void {
        self.unmount();
        
        // Clean up signals
        self.is_mounted.deinit();
        self.allocator.destroy(self.is_mounted);
        self.needs_render.deinit();
        self.allocator.destroy(self.needs_render);
        
        // Clean up component state
        self.component_vtable.destroy(self.component_state, self.allocator);
        
        self.allocator.destroy(self);
    }
};

/// Helper to create a typed reactive component
pub fn createComponent(
    comptime T: type,
    allocator: std.mem.Allocator,
    component_data: T,
    comptime vtable: ReactiveComponent.ComponentVTable
) !*ReactiveComponent {
    const component_ptr = try allocator.create(T);
    component_ptr.* = component_data;
    
    const reactive_component = try allocator.create(ReactiveComponent);
    reactive_component.* = try ReactiveComponent.init(
        allocator,
        @as(*anyopaque, @ptrCast(component_ptr)),
        &vtable
    );
    
    return reactive_component;
}

/// Helper to get typed component data from reactive component
pub fn getComponentData(comptime T: type, reactive_component: *ReactiveComponent) *T {
    return @as(*T, @ptrCast(@alignCast(reactive_component.component_state)));
}

// Example usage and testing
const TestComponent = struct {
    name: []const u8,
    render_count: u32 = 0,
    
    fn onMount(state: *anyopaque) !void {
        const self = @as(*TestComponent, @ptrCast(@alignCast(state)));
        std.debug.print("TestComponent '{}' mounted\n", .{self.name});
    }
    
    fn onUnmount(state: *anyopaque) void {
        const self = @as(*TestComponent, @ptrCast(@alignCast(state)));
        std.debug.print("TestComponent '{}' unmounted\n", .{self.name});
    }
    
    fn onRender(state: *anyopaque) !void {
        const self = @as(*TestComponent, @ptrCast(@alignCast(state)));
        self.render_count += 1;
        std.debug.print("TestComponent '{}' rendered (count: {})\n", .{ self.name, self.render_count });
    }
    
    fn shouldRender(state: *anyopaque) bool {
        const self = @as(*TestComponent, @ptrCast(@alignCast(state)));
        // Only render if count is less than 5 (example optimization)
        return self.render_count < 5;
    }
    
    fn destroy(state: *anyopaque, allocator: std.mem.Allocator) void {
        const self = @as(*TestComponent, @ptrCast(@alignCast(state)));
        std.debug.print("TestComponent '{}' destroyed\n", .{self.name});
        allocator.destroy(self);
    }
    
    const vtable = ReactiveComponent.ComponentVTable{
        .onMount = TestComponent.onMount,
        .onUnmount = TestComponent.onUnmount,
        .onRender = TestComponent.onRender,
        .shouldRender = TestComponent.shouldRender,
        .destroy = TestComponent.destroy,
    };
};

test "reactive component lifecycle" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize reactive context
    try context.initContext(allocator);
    defer context.deinitContext(allocator);
    try batch.initGlobalBatcher(allocator);
    defer batch.deinitGlobalBatcher(allocator);
    
    // Create test component
    var comp = try createComponent(
        TestComponent,
        allocator,
        TestComponent{ .name = "test" },
        TestComponent.vtable
    );
    defer comp.deinit();
    
    // Test lifecycle
    try std.testing.expect(!comp.isMounted());
    
    try comp.mount();
    try std.testing.expect(comp.isMounted());
    
    // Request additional render
    comp.requestRender();
    
    // Unmount
    comp.unmount();
    try std.testing.expect(!comp.isMounted());
}