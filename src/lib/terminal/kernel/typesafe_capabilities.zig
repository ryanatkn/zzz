const std = @import("std");
const events = @import("events.zig");
const descriptors = @import("capability_descriptors.zig");

// Re-export the new data-oriented types
pub const CapabilityType = descriptors.CapabilityType;
pub const CapabilityData = descriptors.CapabilityData;
pub const CapabilityMetadata = descriptors.CapabilityMetadata;
pub const CapabilityDescriptor = descriptors.CapabilityDescriptor;
pub const BuiltinRegistry = descriptors.BuiltinRegistry;

/// Type-safe capability wrapper for registry operations
pub const TypeSafeCapability = struct {
    data: CapabilityData,
    initialized: bool = false,
    
    const Self = @This();
    
    /// Get capability name via dispatch
    pub fn getName(self: Self) []const u8 {
        return descriptors.DispatchTable.getName(self.data);
    }
    
    /// Get capability type
    pub fn getType(self: Self) CapabilityType {
        return self.data.getType();
    }
    
    /// Get dependencies from descriptor
    pub fn getDependencies(self: Self) []const CapabilityType {
        return BuiltinRegistry.getMetadata(self.data.getType()).dependencies;
    }
    
    /// Initialize capability
    pub fn initialize(self: *Self, dependencies: []const TypeSafeCapability, event_bus: *events.EventBus) !void {
        try descriptors.DispatchTable.initialize(self.data, dependencies, event_bus);
        self.initialized = true;
    }
    
    /// Deinitialize capability
    pub fn deinit(self: *Self) void {
        if (self.initialized) {
            descriptors.DispatchTable.deinit(self.data);
            self.initialized = false;
        }
    }
    
    /// Destroy capability (deinit + free memory)
    pub fn destroy(self: Self, allocator: std.mem.Allocator) void {
        descriptors.DispatchTable.destroy(self.data, allocator);
    }
    
    /// Check if capability is active
    pub fn isActive(self: Self) bool {
        // For now, active if initialized
        return self.initialized;
    }
    
    /// Type-safe casting to concrete capability type
    pub fn cast(self: Self, comptime T: type) ?*T {
        return self.data.cast(T);
    }
};

/// Registry entry for efficient storage and lookup
const RegistryEntry = struct {
    capability: TypeSafeCapability,
    dependencies_resolved: bool = false,
};

/// Maximum number of capabilities that can be registered
const MAX_CAPABILITIES = 32;

/// High-performance type-safe capability registry using data-oriented design
pub const TypeSafeCapabilityRegistry = struct {
    allocator: std.mem.Allocator,
    entries: [MAX_CAPABILITIES]RegistryEntry = undefined,
    entry_count: usize = 0,
    event_bus: events.EventBus,
    
    const Self = @This();
    
    /// Initialize registry with event bus
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .entry_count = 0,
            .event_bus = events.EventBus.init(allocator),
        };
    }
    
    /// Clean up all capabilities and resources
    pub fn deinit(self: *Self) void {
        // Destroy all capabilities in reverse order (destroy handles deinit internally)
        var i = self.entry_count;
        while (i > 0) {
            i -= 1;
            // Destroy the capability data (includes deinit + free memory)
            self.entries[i].capability.destroy(self.allocator);
        }
        self.entry_count = 0;
    }
    
    /// Register a capability by type (using descriptor system)
    pub fn registerType(self: *Self, capability_type: CapabilityType) !void {
        if (self.entry_count >= MAX_CAPABILITIES) {
            return error.TooManyCapabilities;
        }
        
        // Check for duplicate types
        for (self.entries[0..self.entry_count]) |entry| {
            if (entry.capability.getType() == capability_type) {
                return error.DuplicateCapability;
            }
        }
        
        // Create capability using factory
        const factory = BuiltinRegistry.getFactory(capability_type);
        const capability_data = try factory(self.allocator);
        
        // Add to registry
        self.entries[self.entry_count] = RegistryEntry{
            .capability = TypeSafeCapability{
                .data = capability_data,
                .initialized = false,
            },
            .dependencies_resolved = false,
        };
        self.entry_count += 1;
    }
    
    /// Register multiple capabilities by type
    pub fn registerTypes(self: *Self, capability_types: []const CapabilityType) !void {
        for (capability_types) |cap_type| {
            try self.registerType(cap_type);
        }
    }
    
    /// Get capability by type - O(1) average case
    pub fn getCapability(self: *Self, capability_type: CapabilityType) ?*TypeSafeCapability {
        for (self.entries[0..self.entry_count]) |*entry| {
            if (entry.capability.getType() == capability_type) {
                return &entry.capability;
            }
        }
        return null;
    }
    
    /// Get typed capability pointer - type-safe access
    pub fn getCapabilityTyped(self: *Self, comptime T: type) ?*T {
        for (self.entries[0..self.entry_count]) |*entry| {
            if (entry.capability.data.cast(T)) |typed_ptr| {
                if (entry.capability.initialized) {
                    return typed_ptr;
                }
            }
        }
        return null;
    }
    
    /// Initialize all capabilities in dependency order
    pub fn initializeAll(self: *Self) !void {
        // Use precomputed initialization order from dependency graph
        const init_order = BuiltinRegistry.dependency_graph.initialization_order;
        
        for (init_order) |cap_type| {
            if (self.getCapability(cap_type)) |capability| {
                if (!capability.initialized) {
                    // Collect resolved dependencies
                    const deps = try self.resolveDependencies(capability);
                    defer self.allocator.free(deps);
                    
                    // Initialize the capability
                    try capability.initialize(deps, &self.event_bus);
                }
            }
        }
        
        // Verify all registered capabilities are initialized
        for (self.entries[0..self.entry_count]) |entry| {
            if (!entry.capability.initialized) {
                std.log.err("Failed to initialize capability: {s}", .{entry.capability.getName()});
                return error.InitializationFailed;
            }
        }
    }
    
    /// Resolve dependencies for a capability
    fn resolveDependencies(self: *Self, capability: *TypeSafeCapability) ![]TypeSafeCapability {
        const required_deps = capability.getDependencies();
        var resolved_deps = std.ArrayList(TypeSafeCapability).init(self.allocator);
        
        for (required_deps) |dep_type| {
            if (self.getCapability(dep_type)) |dep_capability| {
                if (dep_capability.initialized) {
                    try resolved_deps.append(dep_capability.*);
                } else {
                    return error.UnresolvedDependency;
                }
            } else {
                return error.MissingDependency;
            }
        }
        
        return resolved_deps.toOwnedSlice();
    }
    
    /// Get event bus for capability communication
    pub fn getEventBus(self: *Self) *events.EventBus {
        return &self.event_bus;
    }
    
    /// Get capability count
    pub fn getCapabilityCount(self: *const Self) usize {
        return self.entry_count;
    }
    
    /// Get initialized capability count
    pub fn getInitializedCount(self: *const Self) usize {
        var count: usize = 0;
        for (self.entries[0..self.entry_count]) |entry| {
            if (entry.capability.initialized) {
                count += 1;
            }
        }
        return count;
    }
};

/// Create a TypeSafeCapability from capability data
pub fn createCapability(capability_data: CapabilityData) TypeSafeCapability {
    return TypeSafeCapability{
        .data = capability_data,
        .initialized = false,
    };
}

/// Create a new capability registry
pub fn createRegistry(allocator: std.mem.Allocator) !*TypeSafeCapabilityRegistry {
    const registry = try allocator.create(TypeSafeCapabilityRegistry);
    registry.* = TypeSafeCapabilityRegistry.init(allocator);
    return registry;
}

// Tests for the new system
const testing = std.testing;

test "TypeSafeCapabilityRegistry operations" {
    var registry = TypeSafeCapabilityRegistry.init(testing.allocator);
    defer registry.deinit();
    
    // Register basic capabilities
    try registry.registerType(.keyboard_input);
    try registry.registerType(.basic_writer);
    try registry.registerType(.cursor);
    try registry.registerType(.line_buffer);
    
    try testing.expect(registry.getCapabilityCount() == 4);
    
    // Test capability lookup
    const keyboard = registry.getCapability(.keyboard_input);
    try testing.expect(keyboard != null);
    try testing.expect(keyboard.?.getType() == .keyboard_input);
    
    // Initialize all capabilities
    try registry.initializeAll();
    try testing.expect(registry.getInitializedCount() == 4);
    
    // Test typed access
    const typed_keyboard = registry.getCapabilityTyped(@import("../capabilities/input/keyboard.zig").KeyboardInput);
    try testing.expect(typed_keyboard != null);
}

test "Dependency resolution" {
    var registry = TypeSafeCapabilityRegistry.init(testing.allocator);
    defer registry.deinit();
    
    // Register capabilities with dependencies
    try registry.registerType(.keyboard_input);  // No dependencies
    try registry.registerType(.cursor);         // No dependencies
    try registry.registerType(.line_buffer);    // No dependencies
    try registry.registerType(.readline_input); // Depends on above
    
    // Should initialize in correct order
    try registry.initializeAll();
    try testing.expect(registry.getInitializedCount() == 4);
}

test "Missing dependency detection" {
    var registry = TypeSafeCapabilityRegistry.init(testing.allocator);
    defer registry.deinit();
    
    // Register capability without its dependencies
    try registry.registerType(.readline_input); // Missing keyboard_input, cursor, line_buffer
    
    // Should fail to initialize
    try testing.expectError(error.MissingDependency, registry.initializeAll());
}