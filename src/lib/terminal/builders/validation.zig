const std = @import("std");
const terminal_builder = @import("terminal_builder.zig");
const capability_loader = @import("capability_loader.zig");
const CapabilityType = terminal_builder.CapabilityType;
const CapabilityLoader = capability_loader.CapabilityLoader;
const CapabilityMetadata = capability_loader.CapabilityMetadata;

/// Validation result for a capability configuration with bounded storage
pub const ValidationResult = struct {
    is_valid: bool,
    errors: std.BoundedArray(ValidationError, 16), // Max 16 errors should be sufficient
    warnings: std.BoundedArray(ValidationWarning, 32), // Max 32 warnings

    pub fn init() ValidationResult {
        return .{
            .is_valid = true,
            .errors = .{},
            .warnings = .{},
        };
    }

    // No deinit needed - no dynamic allocation
    pub fn deinit(self: *ValidationResult) void {
        _ = self;
    }

    pub fn addError(self: *ValidationResult, error_info: ValidationError) error{Overflow}!void {
        self.errors.append(error_info) catch return error.Overflow;
        self.is_valid = false;
    }

    pub fn addWarning(self: *ValidationResult, warning_info: ValidationWarning) error{Overflow}!void {
        self.warnings.append(warning_info) catch return error.Overflow;
    }
};

/// Validation error information
pub const ValidationError = struct {
    error_type: ErrorType,
    capability: CapabilityType,
    message: []const u8,

    pub const ErrorType = enum {
        missing_dependency,
        capability_conflict,
        invalid_combination,
        circular_dependency,
        unknown_capability,
    };
};

/// Validation warning information
pub const ValidationWarning = struct {
    warning_type: WarningType,
    capability: ?CapabilityType,
    message: []const u8,

    pub const WarningType = enum {
        performance_impact,
        redundant_capability,
        deprecated_capability,
        suboptimal_combination,
    };
};

/// Terminal validation system with arena-based temporary allocations
pub const ValidationSystem = struct {
    allocator: std.mem.Allocator,
    loader: CapabilityLoader,

    /// Initialize validation system
    pub fn init(allocator: std.mem.Allocator) !ValidationSystem {
        return .{
            .allocator = allocator,
            .loader = try CapabilityLoader.init(allocator),
        };
    }

    /// Clean up validation system
    pub fn deinit(self: *ValidationSystem) void {
        self.loader.deinit();
    }

    /// Validate a capability configuration using arena for temporary allocations
    pub fn validateCapabilities(self: *ValidationSystem, capabilities: []const CapabilityType) !ValidationResult {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const temp_allocator = arena.allocator();

        var result = ValidationResult.init();

        // Check for unknown capabilities
        try self.validateKnownCapabilities(capabilities, &result, temp_allocator);

        // Check for missing dependencies
        try self.validateDependencies(capabilities, &result, temp_allocator);

        // Check for conflicts
        try self.validateConflicts(capabilities, &result, temp_allocator);

        // Check for circular dependencies
        try self.validateCircularDependencies(capabilities, &result, temp_allocator);

        // Check for performance implications
        try self.validatePerformance(capabilities, &result, temp_allocator);

        // Check for redundant capabilities
        try self.validateRedundancy(capabilities, &result, temp_allocator);

        return result;
    }

    /// Validate that all capabilities are known/supported
    fn validateKnownCapabilities(self: *ValidationSystem, capabilities: []const CapabilityType, result: *ValidationResult, allocator: std.mem.Allocator) !void {
        _ = allocator; // Using static strings, no allocation needed
        for (capabilities) |cap_type| {
            if (self.loader.getMetadata(cap_type) == null) {
                try result.addError(ValidationError{
                    .error_type = .unknown_capability,
                    .capability = cap_type,
                    .message = "Unknown or unsupported capability",
                });
            }
        }
    }

    /// Validate that all required dependencies are present
    fn validateDependencies(self: *ValidationSystem, capabilities: []const CapabilityType, result: *ValidationResult, allocator: std.mem.Allocator) !void {
        _ = allocator; // Using static strings, no allocation needed
        for (capabilities) |cap_type| {
            if (self.loader.getMetadata(cap_type)) |metadata| {
                for (metadata.dependencies) |dependency| {
                    var found = false;
                    for (capabilities) |other_cap| {
                        if (other_cap == dependency) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        const message = try std.fmt.allocPrint(self.allocator, "Missing required dependency: {s} requires {s}", .{ @tagName(cap_type), @tagName(dependency) });
                        defer self.allocator.free(message);
                        try result.addError(ValidationError{
                            .error_type = .missing_dependency,
                            .capability = cap_type,
                            .message = message,
                        });
                    }
                }
            }
        }
    }

    /// Validate that no capabilities conflict with each other
    fn validateConflicts(self: *ValidationSystem, capabilities: []const CapabilityType, result: *ValidationResult, allocator: std.mem.Allocator) !void {
        for (capabilities) |cap_type| {
            if (self.loader.getMetadata(cap_type)) |metadata| {
                for (metadata.conflicts) |conflict| {
                    for (capabilities) |other_cap| {
                        if (other_cap == conflict) {
                            const message = try std.fmt.allocPrint(allocator, "Capability conflict: {s} conflicts with {s}", .{ @tagName(cap_type), @tagName(conflict) });
                            try result.addError(ValidationError{
                                .error_type = .capability_conflict,
                                .capability = cap_type,
                                .message = message,
                            });
                        }
                    }
                }
            }
        }
    }

    /// Check for circular dependencies using depth-first search
    fn validateCircularDependencies(self: *ValidationSystem, capabilities: []const CapabilityType, result: *ValidationResult, allocator: std.mem.Allocator) !void {
        // Use DFS with coloring to detect cycles - using arena allocator for temporary data
        // White (0) = unvisited, Gray (1) = in progress, Black (2) = completed
        var color_map = std.HashMap(CapabilityType, u8, std.hash_map.AutoContext(CapabilityType), std.hash_map.default_max_load_percentage).init(allocator);
        defer color_map.deinit();

        // Initialize all capabilities as white
        for (capabilities) |cap| {
            try color_map.put(cap, 0);
        }

        // DFS from each capability
        for (capabilities) |cap| {
            if (color_map.get(cap).? == 0) { // If white
                var path = std.ArrayList(CapabilityType).init(allocator);
                defer path.deinit();
                try self.dfsCircularCheck(cap, &color_map, &path, result, allocator);
            }
        }
    }

    /// Depth-first search helper for circular dependency detection
    fn dfsCircularCheck(self: *ValidationSystem, current: CapabilityType, color_map: *std.HashMap(CapabilityType, u8, std.hash_map.AutoContext(CapabilityType), std.hash_map.default_max_load_percentage), path: *std.ArrayList(CapabilityType), result: *ValidationResult, allocator: std.mem.Allocator) error{ OutOfMemory, Overflow }!void {
        // Mark current as gray (in progress)
        try color_map.put(current, 1);
        try path.append(current);

        // Check dependencies
        if (self.loader.getMetadata(current)) |metadata| {
            for (metadata.dependencies) |dep| {
                const dep_color = color_map.get(dep) orelse 0; // Default to white if not found

                if (dep_color == 1) { // Gray = cycle detected
                    // Build cycle path for error message
                    var cycle_start: ?usize = null;
                    for (path.items, 0..) |path_cap, i| {
                        if (path_cap == dep) {
                            cycle_start = i;
                            break;
                        }
                    }

                    var cycle_path = std.ArrayList([]const u8).init(allocator);
                    defer cycle_path.deinit();

                    if (cycle_start) |start| {
                        for (path.items[start..]) |cap| {
                            try cycle_path.append(@tagName(cap));
                        }
                        try cycle_path.append(@tagName(dep));
                    }

                    const cycle_str = try std.mem.join(allocator, " -> ", cycle_path.items);
                    // No need to free cycle_str - arena allocator will clean it up

                    const message = try std.fmt.allocPrint(allocator, "Circular dependency detected: {s}", .{cycle_str});
                    // No need to free message - arena allocator will clean it up

                    try result.addError(ValidationError{
                        .error_type = .circular_dependency,
                        .capability = current,
                        .message = message,
                    });
                } else if (dep_color == 0) { // White = continue DFS
                    try self.dfsCircularCheck(dep, color_map, path, result, allocator);
                }
            }
        }

        // Mark current as black (completed)
        try color_map.put(current, 2);
        _ = path.pop(); // Remove from current path
    }

    /// Check for performance implications
    fn validatePerformance(self: *ValidationSystem, capabilities: []const CapabilityType, result: *ValidationResult, allocator: std.mem.Allocator) !void {
        _ = allocator; // Using static strings, no allocation needed
        // Check for potentially expensive combinations
        var has_buffered_output = false;
        var has_ansi_writer = false;

        for (capabilities) |cap_type| {
            switch (cap_type) {
                .buffered_output => has_buffered_output = true,
                .ansi_writer => has_ansi_writer = true,
                else => {},
            }
        }

        if (has_buffered_output and has_ansi_writer) {
            try result.addWarning(ValidationWarning{
                .warning_type = .performance_impact,
                .capability = null,
                .message = "BufferedOutput with AnsiWriter may have reduced performance due to escape sequence processing",
            });
        }

        // Check for high memory usage combinations
        var state_capabilities: u32 = 0;
        for (capabilities) |cap_type| {
            if (self.loader.getMetadata(cap_type)) |metadata| {
                if (metadata.category == .state) {
                    state_capabilities += 1;
                }
            }
        }

        if (state_capabilities > 4) {
            try result.addWarning(ValidationWarning{
                .warning_type = .performance_impact,
                .capability = null,
                .message = "High number of state capabilities may increase memory usage",
            });
        }
    }

    /// Check for redundant capabilities
    fn validateRedundancy(self: *ValidationSystem, capabilities: []const CapabilityType, result: *ValidationResult, allocator: std.mem.Allocator) !void {
        _ = allocator; // Using static strings, no allocation needed
        // Check for multiple input capabilities
        var input_count: u32 = 0;
        var output_count: u32 = 0;

        for (capabilities) |cap_type| {
            if (self.loader.getMetadata(cap_type)) |metadata| {
                switch (metadata.category) {
                    .input => input_count += 1,
                    .output => output_count += 1,
                    else => {},
                }
            }
        }

        if (input_count > 2) {
            try result.addWarning(ValidationWarning{
                .warning_type = .redundant_capability,
                .capability = null,
                .message = "Multiple input capabilities may cause conflicts or redundancy",
            });
        }

        if (output_count > 2) {
            try result.addWarning(ValidationWarning{
                .warning_type = .redundant_capability,
                .capability = null,
                .message = "Multiple output capabilities may cause conflicts or redundancy",
            });
        }
    }

    /// Get recommended capabilities for a use case
    pub fn getRecommendedCapabilities(self: *ValidationSystem, use_case: UseCase, recommended: *std.ArrayList(CapabilityType)) !void {
        switch (use_case) {
            .minimal_terminal => {
                const caps = &[_]CapabilityType{ .keyboard_input, .basic_writer, .line_buffer, .cursor };
                try recommended.appendSlice(caps);
            },
            .interactive_shell => {
                const caps = &[_]CapabilityType{ .readline_input, .ansi_writer, .line_buffer, .cursor, .history, .screen_buffer, .scrollback, .persistence, .parser, .registry, .executor, .builtin, .pipeline };
                try recommended.appendSlice(caps);
            },
            .logging_terminal => {
                const caps = &[_]CapabilityType{ .keyboard_input, .buffered_output, .screen_buffer, .scrollback, .persistence };
                try recommended.appendSlice(caps);
            },
            .embedded_terminal => {
                const caps = &[_]CapabilityType{ .keyboard_input, .basic_writer, .line_buffer, .cursor };
                try recommended.appendSlice(caps);
            },
        }

        _ = self; // Unused for now
    }

    /// Common terminal use cases
    pub const UseCase = enum {
        minimal_terminal,
        interactive_shell,
        logging_terminal,
        embedded_terminal,
    };
};
