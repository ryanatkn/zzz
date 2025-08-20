const std = @import("std");
const descriptors = @import("../kernel/capability_descriptors.zig");

// Use new data-oriented types
pub const CapabilityType = descriptors.CapabilityType;
pub const CapabilityMetadata = descriptors.CapabilityMetadata;
pub const BuiltinRegistry = descriptors.BuiltinRegistry;

/// Data-oriented capability discovery and loading system
pub const CapabilityLoader = struct {
    allocator: std.mem.Allocator,
    
    const Self = @This();
    
    /// Initialize capability loader - no longer needs to build metadata maps
    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
        };
    }
    
    /// Clean up loader resources - nothing to clean with new system
    pub fn deinit(self: *Self) void {
        _ = self;
    }
    
    /// Get metadata for a capability type - O(1) with new system
    pub fn getMetadata(self: *Self, cap_type: CapabilityType) ?CapabilityMetadata {
        _ = self;
        return BuiltinRegistry.getMetadata(cap_type);
    }
    
    /// Get all capabilities in a category
    pub fn getCapabilitiesByCategory(self: *Self, category: descriptors.CapabilityCategory, result: *std.ArrayList(CapabilityType)) !void {
        _ = self;
        
        // Iterate through all builtin descriptors
        inline for (BuiltinRegistry.descriptors) |desc| {
            if (desc.metadata.category == category) {
                try result.append(desc.type);
            }
        }
    }
    
    /// Resolve dependencies for a set of capabilities using precomputed graph
    pub fn resolveDependencies(self: *Self, requested: []const CapabilityType, resolved: *std.ArrayList(CapabilityType)) !void {
        
        // Use precomputed dependency graph for efficient resolution
        const dependency_graph = BuiltinRegistry.dependency_graph;
        
        // Create set of requested capabilities for lookup
        var requested_set = std.HashMap(CapabilityType, void, std.hash_map.AutoContext(CapabilityType), std.hash_map.default_max_load_percentage).init(self.allocator);
        defer requested_set.deinit();
        
        for (requested) |cap_type| {
            try requested_set.put(cap_type, {});
        }
        
        // Add capabilities in dependency order
        for (dependency_graph.initialization_order) |cap_type| {
            // Check if this capability is needed (either requested or dependency of requested)
            if (requested_set.contains(cap_type) or self.isDependencyOfRequested(cap_type, requested)) {
                try resolved.append(cap_type);
            }
        }
    }
    
    /// Check if capability is a dependency of any requested capabilities
    fn isDependencyOfRequested(self: *Self, cap_type: CapabilityType, requested: []const CapabilityType) bool {
        
        for (requested) |req_type| {
            const metadata = BuiltinRegistry.getMetadata(req_type);
            for (metadata.dependencies) |dep| {
                if (dep == cap_type) return true;
            }
            // Check transitive dependencies recursively
            for (metadata.dependencies) |dep| {
                if (self.isDependencyOfRequested(cap_type, &[_]CapabilityType{dep})) {
                    return true;
                }
            }
        }
        return false;
    }
    
    /// Validate that a set of capabilities is compatible using descriptor data
    pub fn validateCompatibility(self: *Self, capabilities: []const CapabilityType) !void {
        _ = self;
        
        // Check for conflicts using descriptor metadata
        for (capabilities) |cap_type| {
            const metadata = BuiltinRegistry.getMetadata(cap_type);
            for (metadata.conflicts) |conflict| {
                for (capabilities) |other_cap| {
                    if (other_cap == conflict) {
                        std.log.err("Capability conflict: {s} conflicts with {s}", .{ 
                            metadata.name, 
                            BuiltinRegistry.getMetadata(conflict).name 
                        });
                        return error.CapabilityConflict;
                    }
                }
            }
        }
        
        // Check for missing dependencies using descriptor metadata
        for (capabilities) |cap_type| {
            const metadata = BuiltinRegistry.getMetadata(cap_type);
            for (metadata.dependencies) |dependency| {
                var found = false;
                for (capabilities) |other_cap| {
                    if (other_cap == dependency) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    std.log.err("Missing dependency: {s} requires {s}", .{ 
                        metadata.name, 
                        BuiltinRegistry.getMetadata(dependency).name 
                    });
                    return error.MissingDependency;
                }
            }
        }
    }
    
    /// Load capability from external plugin (future extension point)
    pub fn loadPlugin(self: *Self, plugin_path: []const u8) !void {
        _ = self;
        _ = plugin_path;
        std.log.warn("Plugin loading not yet implemented", .{});
    }
    
    /// Get recommended capabilities for a use case
    pub fn getRecommendedCapabilities(self: *Self, use_case: UseCase, recommended: *std.ArrayList(CapabilityType)) !void {
        _ = self;
        
        const caps = switch (use_case) {
            .minimal_terminal => &[_]CapabilityType{ .keyboard_input, .basic_writer, .line_buffer, .cursor },
            .interactive_shell => &[_]CapabilityType{
                .readline_input, .ansi_writer, .line_buffer, .cursor, 
                .history, .screen_buffer, .scrollback, .persistence,
                .parser, .registry, .executor, .builtin, .pipeline
            },
            .logging_terminal => &[_]CapabilityType{
                .keyboard_input, .buffered_output, .screen_buffer, 
                .scrollback, .persistence
            },
            .embedded_terminal => &[_]CapabilityType{
                .keyboard_input, .basic_writer, .line_buffer, .cursor
            },
        };
        
        try recommended.appendSlice(caps);
    }
    
    /// Common terminal use cases
    pub const UseCase = enum {
        minimal_terminal,
        interactive_shell,
        logging_terminal,
        embedded_terminal,
    };
};