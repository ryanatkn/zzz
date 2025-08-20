const std = @import("std");
const kernel = @import("../kernel/mod.zig");
const descriptors = @import("../kernel/capability_descriptors.zig");

// Use new data-oriented types
pub const CapabilityType = descriptors.CapabilityType;
pub const CapabilityData = descriptors.CapabilityData;
pub const BuiltinRegistry = descriptors.BuiltinRegistry;
const TypeSafeCapabilityRegistry = kernel.TypeSafeCapabilityRegistry;

/// Preset configurations for common terminal types
pub const PresetType = enum {
    minimal,     // keyboard + basic_writer + line_buffer + cursor
    standard,    // minimal + history + screen_buffer + scrollback + persistence
    command,     // standard + all command capabilities
};

/// Configuration options for capabilities (future extension)
pub const CapabilityConfig = struct {
    // Future: capability-specific config options
};

/// Data-oriented terminal builder with fluent API and delayed error handling
pub const TerminalBuilder = struct {
    allocator: std.mem.Allocator,
    capabilities: std.BoundedArray(CapabilityType, 32), // Fixed size, no allocation failures
    config: ?CapabilityConfig,
    error_state: ?anyerror, // Track first error encountered
    
    const Self = @This();
    
    /// Initialize a new terminal builder
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .capabilities = std.BoundedArray(CapabilityType, 32){},
            .config = null,
            .error_state = null,
        };
    }
    
    /// Clean up builder resources (nothing to clean with BoundedArray)
    pub fn deinit(self: *Self) void {
        _ = self; // No cleanup needed
    }
    
    /// Add a capability to the terminal
    pub fn withCapability(self: *Self, capability_type: CapabilityType) *Self {
        if (self.error_state != null) return self; // Skip if already errored
        
        self.capabilities.append(capability_type) catch |err| {
            self.error_state = err;
        };
        return self;
    }
    
    /// Add multiple capabilities at once
    pub fn withCapabilities(self: *Self, capability_types: []const CapabilityType) *Self {
        if (self.error_state != null) return self; // Skip if already errored
        
        for (capability_types) |cap_type| {
            self.capabilities.append(cap_type) catch |err| {
                self.error_state = err;
                break;
            };
        }
        return self;
    }
    
    /// Use a preset configuration
    pub fn withPreset(self: *Self, preset: PresetType) *Self {
        if (self.error_state != null) return self; // Skip if already errored
        
        const preset_capabilities = switch (preset) {
            .minimal => &[_]CapabilityType{
                .keyboard_input,
                .basic_writer,
                .line_buffer,
                .cursor,
            },
            .standard => &[_]CapabilityType{
                .keyboard_input,
                .basic_writer,
                .line_buffer,
                .cursor,
                .history,
                .screen_buffer,
                .scrollback,
                .persistence,
            },
            .command => &[_]CapabilityType{
                .keyboard_input,
                .basic_writer,
                .line_buffer,
                .cursor,
                .history,
                .screen_buffer,
                .scrollback,
                .persistence,
                .parser,
                .registry,
                .executor,
                .builtin,
                .pipeline,
                .ansi_writer,
            },
        };
        
        return self.withCapabilities(preset_capabilities);
    }
    
    /// Set configuration options
    pub fn withConfig(self: *Self, config: CapabilityConfig) *Self {
        if (self.error_state != null) return self; // Skip if already errored
        self.config = config;
        return self;
    }
    
    /// Load configuration from file
    pub fn withConfigFile(self: *Self, path: []const u8) *Self {
        if (self.error_state != null) return self; // Skip if already errored
        
        // TODO: Implement config file loading
        _ = path;
        std.log.warn("Config file loading not yet implemented", .{});
        return self;
    }
    
    /// Build the terminal with all configured capabilities
    pub fn build(self: *Self) !BuiltTerminal {
        // Check for accumulated errors first
        if (self.error_state) |err| {
            return err;
        }
        
        if (self.capabilities.len == 0) {
            return error.NoCapabilities;
        }
        
        // Create registry using new data-oriented system
        var registry = try kernel.createRegistry(self.allocator);
        errdefer self.allocator.destroy(registry);
        
        // Register all capabilities using the new type-based system
        try registry.registerTypes(self.capabilities.slice());
        
        // Initialize all capabilities using precomputed dependency order
        try registry.initializeAll();
        
        return BuiltTerminal{
            .allocator = self.allocator,
            .registry = registry,
            .capability_count = self.capabilities.len,
        };
    }
};

/// Result of building a terminal - streamlined interface
pub const BuiltTerminal = struct {
    allocator: std.mem.Allocator,
    registry: *TypeSafeCapabilityRegistry,
    capability_count: usize,
    
    const Self = @This();
    
    /// Get a capability of the specified type
    pub fn getCapability(self: *Self, comptime T: type) ?*T {
        return self.registry.getCapabilityTyped(T);
    }
    
    /// Execute a command (if command capabilities are present)
    pub fn executeCommand(self: *Self, command: []const u8) !void {
        // TODO: Implement command execution through pipeline
        _ = self;
        _ = command;
        std.log.warn("Command execution not yet implemented in builder", .{});
    }
    
    /// Write text to the terminal (if writer capabilities are present)
    pub fn write(self: *Self, text: []const u8) !void {
        const BasicWriter = @import("../capabilities/output/basic_writer.zig").BasicWriter;
        const AnsiWriter = @import("../capabilities/output/ansi_writer.zig").AnsiWriter;
        
        if (self.getCapability(BasicWriter)) |writer| {
            try writer.write(text);
        } else if (self.getCapability(AnsiWriter)) |ansi_writer| {
            try ansi_writer.write(text);
        } else {
            return error.NoWriterCapability;
        }
    }
    
    /// Clean up all terminal resources - simplified with new data-oriented system
    pub fn deinit(self: *Self) void {
        // Registry cleanup is now handled by the registry itself
        self.registry.deinit();
        self.allocator.destroy(self.registry);
    }
};