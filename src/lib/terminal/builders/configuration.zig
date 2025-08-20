const std = @import("std");
const terminal_builder = @import("terminal_builder.zig");
const CapabilityType = terminal_builder.CapabilityType;
const PresetType = terminal_builder.PresetType;

/// Configuration formats supported by the system
pub const ConfigFormat = enum {
    json,
    // TODO: Add TOML, ZON support when parsers available
    // toml,
    // zon,
};

/// Terminal configuration loaded from external sources
pub const TerminalConfig = struct {
    preset: ?PresetType = null,
    capabilities: []CapabilityType = &[_]CapabilityType{},
    capability_configs: std.HashMap(CapabilityType, CapabilitySpecificConfig, std.hash_map.AutoContext(CapabilityType), std.hash_map.default_max_load_percentage),
    
    const Self = @This();
    
    /// Initialize empty configuration
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .capability_configs = std.HashMap(CapabilityType, CapabilitySpecificConfig, std.hash_map.AutoContext(CapabilityType), std.hash_map.default_max_load_percentage).init(allocator),
        };
    }
    
    /// Clean up configuration resources
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        if (self.capabilities.len > 0) {
            allocator.free(self.capabilities);
        }
        self.capability_configs.deinit();
    }
};

/// Capability-specific configuration options
pub const CapabilitySpecificConfig = struct {
    // TODO: Add capability-specific configuration fields
    // For now, using a generic key-value store
    options: std.HashMap([]const u8, []const u8, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .options = std.HashMap([]const u8, []const u8, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.options.deinit();
    }
};

/// Configuration system for loading terminal settings
pub const ConfigurationSystem = struct {
    allocator: std.mem.Allocator,
    
    const Self = @This();
    
    /// Initialize configuration system
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }
    
    /// Load configuration from file
    pub fn loadFromFile(self: *Self, file_path: []const u8) !TerminalConfig {
        const file_extension = std.fs.path.extension(file_path);
        const format = if (std.mem.eql(u8, file_extension, ".json"))
            ConfigFormat.json
        else
            return error.UnsupportedConfigFormat;
        
        const file_content = try self.readFile(file_path);
        defer self.allocator.free(file_content);
        
        return switch (format) {
            .json => try self.parseJson(file_content),
        };
    }
    
    /// Load configuration from environment variables
    pub fn loadFromEnvironment(self: *Self) !TerminalConfig {
        var config = TerminalConfig.init(self.allocator);
        
        // Check for preset environment variable
        if (std.process.getEnvVarOwned(self.allocator, "TERMINAL_PRESET")) |preset_str| {
            defer self.allocator.free(preset_str);
            
            if (std.mem.eql(u8, preset_str, "minimal")) {
                config.preset = .minimal;
            } else if (std.mem.eql(u8, preset_str, "standard")) {
                config.preset = .standard;
            } else if (std.mem.eql(u8, preset_str, "command")) {
                config.preset = .command;
            }
        } else |_| {
            // Environment variable not set, use default
        }
        
        // TODO: Check for capability-specific environment variables
        
        return config;
    }
    
    /// Create default configuration
    pub fn defaultConfig(self: *Self) TerminalConfig {
        var config = TerminalConfig.init(self.allocator);
        config.preset = .standard; // Default to standard terminal
        return config;
    }
    
    /// Merge multiple configurations (later configs override earlier ones)
    pub fn mergeConfigs(self: *Self, configs: []const TerminalConfig) !TerminalConfig {
        var merged = TerminalConfig.init(self.allocator);
        
        for (configs) |config| {
            // Override preset if specified
            if (config.preset) |preset| {
                merged.preset = preset;
            }
            
            // Merge capabilities (later configs add to the list)
            if (config.capabilities.len > 0) {
                const new_caps = try self.allocator.alloc(CapabilityType, merged.capabilities.len + config.capabilities.len);
                if (merged.capabilities.len > 0) {
                    @memcpy(new_caps[0..merged.capabilities.len], merged.capabilities);
                    self.allocator.free(merged.capabilities);
                }
                @memcpy(new_caps[merged.capabilities.len..], config.capabilities);
                merged.capabilities = new_caps;
            }
            
            // TODO: Merge capability-specific configs
        }
        
        return merged;
    }
    
    /// Validate configuration for consistency
    pub fn validateConfig(self: *Self, config: *const TerminalConfig) !void {
        _ = self;
        _ = config;
        // TODO: Implement configuration validation
        // - Check for conflicting capabilities
        // - Validate capability-specific options
        // - Ensure required dependencies are present
        std.log.info("Configuration validation not yet implemented", .{});
    }
    
    /// Apply configuration to a terminal builder
    pub fn applyToBuilder(self: *Self, config: *const TerminalConfig, builder: *terminal_builder.TerminalBuilder) !void {
        _ = self;
        
        // Apply preset first if specified
        if (config.preset) |preset| {
            _ = try builder.withPreset(preset);
        }
        
        // Add additional capabilities
        if (config.capabilities.len > 0) {
            _ = try builder.withCapabilities(config.capabilities);
        }
        
        // TODO: Apply capability-specific configurations
    }
    
    /// Read file contents
    fn readFile(self: *Self, file_path: []const u8) ![]u8 {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        
        const file_size = try file.getEndPos();
        const content = try self.allocator.alloc(u8, file_size);
        _ = try file.readAll(content);
        
        return content;
    }
    
    /// Parse JSON configuration
    fn parseJson(self: *Self, json_content: []const u8) !TerminalConfig {
        const config = TerminalConfig.init(self.allocator);
        
        // TODO: Implement JSON parsing when std.json is available
        // For now, just return default config with a warning
        _ = json_content;
        std.log.warn("JSON parsing not yet implemented, using default config", .{});
        
        return config;
    }
};

/// Example configuration structures for documentation
pub const ExampleConfigs = struct {
    /// Minimal terminal configuration JSON
    pub const MINIMAL_JSON =
        \\{
        \\  "preset": "minimal",
        \\  "capabilities": []
        \\}
    ;
    
    /// Standard terminal configuration JSON
    pub const STANDARD_JSON =
        \\{
        \\  "preset": "standard",
        \\  "capabilities": []
        \\}
    ;
    
    /// Command terminal configuration JSON
    pub const COMMAND_JSON =
        \\{
        \\  "preset": "command",
        \\  "capabilities": [],
        \\  "capability_configs": {
        \\    "builtin": {
        \\      "enable_help": "true",
        \\      "enable_cd": "true"
        \\    }
        \\  }
        \\}
    ;
    
    /// Custom terminal configuration JSON
    pub const CUSTOM_JSON =
        \\{
        \\  "preset": null,
        \\  "capabilities": [
        \\    "keyboard_input",
        \\    "readline_input",
        \\    "ansi_writer",
        \\    "history",
        \\    "persistence"
        \\  ],
        \\  "capability_configs": {
        \\    "history": {
        \\      "max_entries": "1000"
        \\    },
        \\    "readline_input": {
        \\      "enable_vi_mode": "false"
        \\    }
        \\  }
        \\}
    ;
};