const std = @import("std");
const events = @import("events.zig");

/// Capability interface that all capabilities must implement
pub const ICapability = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Get capability name
        getName: *const fn (ptr: *anyopaque) []const u8,
        
        /// Get capability type
        getType: *const fn (ptr: *anyopaque) []const u8,
        
        /// Get required dependencies
        getDependencies: *const fn (ptr: *anyopaque) []const []const u8,
        
        /// Initialize capability with dependencies
        init: *const fn (ptr: *anyopaque, dependencies: []const ICapability, event_bus: *events.EventBus) anyerror!void,
        
        /// Cleanup capability resources
        deinit: *const fn (ptr: *anyopaque) void,
        
        /// Check if capability is active
        isActive: *const fn (ptr: *anyopaque) bool,
    };

    pub fn getName(self: ICapability) []const u8 {
        return self.vtable.getName(self.ptr);
    }

    pub fn getType(self: ICapability) []const u8 {
        return self.vtable.getType(self.ptr);
    }

    pub fn getDependencies(self: ICapability) []const []const u8 {
        return self.vtable.getDependencies(self.ptr);
    }

    pub fn init(self: ICapability, dependencies: []const ICapability, event_bus: *events.EventBus) !void {
        return self.vtable.init(self.ptr, dependencies, event_bus);
    }

    pub fn deinit(self: ICapability) void {
        self.vtable.deinit(self.ptr);
    }

    pub fn isActive(self: ICapability) bool {
        return self.vtable.isActive(self.ptr);
    }
};

/// Capability registration entry
const CapabilityEntry = struct {
    name: []const u8,
    capability: ICapability,
    initialized: bool,
    dependencies_resolved: bool,
};

/// Capability registry for managing terminal capabilities
pub const CapabilityRegistry = struct {
    entries: [MAX_CAPABILITIES]CapabilityEntry,
    entry_count: usize,
    allocator: std.mem.Allocator,
    event_bus: events.EventBus,

    const MAX_CAPABILITIES = 32;

    pub fn init(allocator: std.mem.Allocator) CapabilityRegistry {
        return CapabilityRegistry{
            .entries = undefined,
            .entry_count = 0,
            .allocator = allocator,
            .event_bus = events.EventBus.init(allocator),
        };
    }

    pub fn deinit(self: *CapabilityRegistry) void {
        // Deinitialize all capabilities in reverse order
        var i = self.entry_count;
        while (i > 0) {
            i -= 1;
            if (self.entries[i].initialized) {
                self.entries[i].capability.deinit();
            }
        }
    }

    /// Register a new capability
    pub fn register(self: *CapabilityRegistry, name: []const u8, capability: ICapability) !void {
        if (self.entry_count >= MAX_CAPABILITIES) {
            return error.TooManyCapabilities;
        }

        // Check for duplicate names
        for (self.entries[0..self.entry_count]) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return error.CapabilityAlreadyExists;
            }
        }

        self.entries[self.entry_count] = CapabilityEntry{
            .name = name,
            .capability = capability,
            .initialized = false,
            .dependencies_resolved = false,
        };
        self.entry_count += 1;

        // Emit capability added event
        const event = events.Event.init(.capability_added, events.EventData{
            .capability_added = events.CapabilityEventData{
                .name = name,
                .capability_type = capability.getType(),
            },
        });
        try self.event_bus.emit(event);
    }

    /// Unregister capability by name
    pub fn unregister(self: *CapabilityRegistry, name: []const u8) void {
        for (self.entries[0..self.entry_count], 0..) |*entry, i| {
            if (std.mem.eql(u8, entry.name, name)) {
                if (entry.initialized) {
                    entry.capability.deinit();
                }

                // Emit capability removed event
                const event = events.Event.init(.capability_removed, events.EventData{
                    .capability_removed = events.CapabilityEventData{
                        .name = name,
                        .capability_type = entry.capability.getType(),
                    },
                });
                self.event_bus.emit(event) catch {};

                // Shift remaining entries
                const remaining = self.entry_count - i - 1;
                if (remaining > 0) {
                    std.mem.copy(
                        CapabilityEntry,
                        self.entries[i..i + remaining],
                        self.entries[i + 1..self.entry_count],
                    );
                }
                self.entry_count -= 1;
                break;
            }
        }
    }

    /// Get capability by name
    pub fn getCapability(self: *const CapabilityRegistry, name: []const u8) ?ICapability {
        for (self.entries[0..self.entry_count]) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return entry.capability;
            }
        }
        return null;
    }
    
    /// Get capability with type safety (compile-time type checking where possible)
    pub fn getCapabilityTyped(self: *const CapabilityRegistry, comptime T: type) ?*T {
        const cap = self.getCapability(T.name) orelse return null;
        
        // In debug builds, verify type matches
        if (std.debug.runtime_safety) {
            std.debug.assert(std.mem.eql(u8, cap.getType(), T.capability_type));
        }
        
        return @ptrCast(@alignCast(cap.ptr));
    }

    /// Check if capability exists
    pub fn hasCapability(self: *const CapabilityRegistry, name: []const u8) bool {
        return self.getCapability(name) != null;
    }
    
    /// Check if capability exists with type
    pub fn hasCapabilityTyped(self: *const CapabilityRegistry, comptime T: type) bool {
        return self.getCapabilityTyped(T) != null;
    }

    /// Resolve dependencies and initialize all capabilities
    pub fn initializeAll(self: *CapabilityRegistry) !void {
        // Initialize in dependency order
        var initialized_any = true;
        while (initialized_any) {
            initialized_any = false;
            // Re-resolve dependencies each iteration since they depend on what's initialized
            try self.resolveDependencies();
            
            for (self.entries[0..self.entry_count]) |*entry| {
                if (!entry.initialized and entry.dependencies_resolved) {
                    try self.initializeCapability(entry);
                    initialized_any = true;
                }
            }
        }

        // Check for uninitialized capabilities (circular dependencies)
        for (self.entries[0..self.entry_count]) |entry| {
            if (!entry.initialized) {
                return error.CircularDependency;
            }
        }
    }

    /// Resolve dependencies for all capabilities
    fn resolveDependencies(self: *CapabilityRegistry) !void {
        for (self.entries[0..self.entry_count]) |*entry| {
            entry.dependencies_resolved = self.canResolveDependencies(entry.capability);
        }
    }

    /// Check if capability dependencies can be resolved
    fn canResolveDependencies(self: *const CapabilityRegistry, capability: ICapability) bool {
        const deps = capability.getDependencies();
        for (deps) |dep_name| {
            // Check if dependency exists and is already initialized
            var found_and_initialized = false;
            for (self.entries[0..self.entry_count]) |entry| {
                if (std.mem.eql(u8, entry.name, dep_name) and entry.initialized) {
                    found_and_initialized = true;
                    break;
                }
            }
            if (!found_and_initialized) {
                return false;
            }
        }
        return true;
    }

    /// Initialize a single capability with its dependencies
    fn initializeCapability(self: *CapabilityRegistry, entry: *CapabilityEntry) !void {
        const deps = entry.capability.getDependencies();
        var resolved_deps = std.ArrayList(ICapability).init(self.allocator);
        defer resolved_deps.deinit();

        // Collect resolved dependencies
        for (deps) |dep_name| {
            if (self.getCapability(dep_name)) |dep_cap| {
                try resolved_deps.append(dep_cap);
            } else {
                return error.UnresolvedDependency;
            }
        }

        // Initialize capability
        try entry.capability.init(resolved_deps.items, &self.event_bus);
        entry.initialized = true;
    }

    /// Get event bus for capability communication
    pub fn getEventBus(self: *CapabilityRegistry) *events.EventBus {
        return &self.event_bus;
    }

    /// Get count of registered capabilities
    pub fn getCapabilityCount(self: *const CapabilityRegistry) usize {
        return self.entry_count;
    }

    /// Get count of initialized capabilities
    pub fn getInitializedCount(self: *const CapabilityRegistry) usize {
        var count: usize = 0;
        for (self.entries[0..self.entry_count]) |entry| {
            if (entry.initialized) count += 1;
        }
        return count;
    }
};