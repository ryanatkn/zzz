const std = @import("std");
const terminal_builder = @import("terminal_builder.zig");
const capability_loader = @import("capability_loader.zig");
const CapabilityType = terminal_builder.CapabilityType;
const CapabilityLoader = capability_loader.CapabilityLoader;
const CapabilityMetadata = capability_loader.CapabilityMetadata;

/// Validation result for a capability configuration
pub const ValidationResult = struct {
    is_valid: bool,
    errors: std.ArrayList(ValidationError),
    warnings: std.ArrayList(ValidationWarning),
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .is_valid = true,
            .errors = std.ArrayList(ValidationError).init(allocator),
            .warnings = std.ArrayList(ValidationWarning).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.errors.deinit();
        self.warnings.deinit();
    }
    
    pub fn addError(self: *Self, error_info: ValidationError) !void {
        self.is_valid = false;
        try self.errors.append(error_info);
    }
    
    pub fn addWarning(self: *Self, warning_info: ValidationWarning) !void {
        try self.warnings.append(warning_info);
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

/// Terminal validation system
pub const ValidationSystem = struct {
    allocator: std.mem.Allocator,
    loader: CapabilityLoader,
    
    const Self = @This();
    
    /// Initialize validation system
    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .loader = try CapabilityLoader.init(allocator),
        };
    }
    
    /// Clean up validation system
    pub fn deinit(self: *Self) void {
        self.loader.deinit();
    }
    
    /// Validate a capability configuration
    pub fn validateCapabilities(self: *Self, capabilities: []const CapabilityType) !ValidationResult {
        var result = ValidationResult.init(self.allocator);
        
        // Check for unknown capabilities
        try self.validateKnownCapabilities(capabilities, &result);
        
        // Check for missing dependencies
        try self.validateDependencies(capabilities, &result);
        
        // Check for conflicts
        try self.validateConflicts(capabilities, &result);
        
        // Check for circular dependencies
        try self.validateCircularDependencies(capabilities, &result);
        
        // Check for performance implications
        try self.validatePerformance(capabilities, &result);
        
        // Check for redundant capabilities
        try self.validateRedundancy(capabilities, &result);
        
        return result;
    }
    
    /// Validate that all capabilities are known/supported
    fn validateKnownCapabilities(self: *Self, capabilities: []const CapabilityType, result: *ValidationResult) !void {
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
    fn validateDependencies(self: *Self, capabilities: []const CapabilityType, result: *ValidationResult) !void {
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
    fn validateConflicts(self: *Self, capabilities: []const CapabilityType, result: *ValidationResult) !void {
        for (capabilities) |cap_type| {
            if (self.loader.getMetadata(cap_type)) |metadata| {
                for (metadata.conflicts) |conflict| {
                    for (capabilities) |other_cap| {
                        if (other_cap == conflict) {
                            const message = try std.fmt.allocPrint(self.allocator, "Capability conflict: {s} conflicts with {s}", .{ @tagName(cap_type), @tagName(conflict) });
                            defer self.allocator.free(message);
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
    
    /// Check for circular dependencies (simplified detection)
    fn validateCircularDependencies(self: *Self, capabilities: []const CapabilityType, result: *ValidationResult) !void {
        // TODO: Implement proper circular dependency detection algorithm
        // For now, just check if any capability depends on itself
        for (capabilities) |cap_type| {
            if (self.loader.getMetadata(cap_type)) |metadata| {
                for (metadata.dependencies) |dependency| {
                    if (dependency == cap_type) {
                        const message = try std.fmt.allocPrint(self.allocator, "Circular dependency: {s} depends on itself", .{@tagName(cap_type)});
                        defer self.allocator.free(message);
                        try result.addError(ValidationError{
                            .error_type = .circular_dependency,
                            .capability = cap_type,
                            .message = message,
                        });
                    }
                }
            }
        }
    }
    
    /// Check for performance implications
    fn validatePerformance(self: *Self, capabilities: []const CapabilityType, result: *ValidationResult) !void {
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
    fn validateRedundancy(self: *Self, capabilities: []const CapabilityType, result: *ValidationResult) !void {
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
    pub fn getRecommendedCapabilities(self: *Self, use_case: UseCase, recommended: *std.ArrayList(CapabilityType)) !void {
        switch (use_case) {
            .minimal_terminal => {
                const caps = &[_]CapabilityType{ .keyboard_input, .basic_writer, .line_buffer, .cursor };
                try recommended.appendSlice(caps);
            },
            .interactive_shell => {
                const caps = &[_]CapabilityType{
                    .readline_input, .ansi_writer, .line_buffer, .cursor, 
                    .history, .screen_buffer, .scrollback, .persistence,
                    .parser, .registry, .executor, .builtin, .pipeline
                };
                try recommended.appendSlice(caps);
            },
            .logging_terminal => {
                const caps = &[_]CapabilityType{
                    .keyboard_input, .buffered_output, .screen_buffer, 
                    .scrollback, .persistence
                };
                try recommended.appendSlice(caps);
            },
            .embedded_terminal => {
                const caps = &[_]CapabilityType{
                    .keyboard_input, .basic_writer, .line_buffer, .cursor
                };
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