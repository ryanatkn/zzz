const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Process execution result
pub const ProcessResult = struct {
    stdout: []u8,
    stderr: []u8,
    exit_code: u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ProcessResult) void {
        self.allocator.free(self.stdout);
        self.allocator.free(self.stderr);
    }
};

/// Process executor capability - handles external process execution
pub const Executor = struct {
    pub const name = "process_executor";
    pub const capability_type = "commands";

    allocator: std.mem.Allocator,
    arena: *std.heap.ArenaAllocator,
    current_process: ?std.process.Child = null,
    working_directory: std.ArrayList(u8),
    environment: std.process.EnvMap,
    event_bus: ?*kernel.EventBus = null,

    // Output streaming callback
    output_callback: ?*const fn (context: *anyopaque, data: []const u8) anyerror!void = null,
    output_context: ?*anyopaque = null,

    const Self = @This();

    /// Factory method for creating executor capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        // Create arena allocator for this capability - allocate it separately so it doesn't move
        const arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        const arena_allocator = arena.allocator();
        
        // Initialize environment with arena allocator
        var env = std.process.EnvMap.init(arena_allocator);

        // Copy current environment - all strings will be allocated in arena
        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();
        var env_iter = env_map.iterator();
        while (env_iter.next()) |entry| {
            try env.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        // Get initial working directory using arena allocator
        var working_dir = std.ArrayList(u8).init(arena_allocator);
        const cwd = std.fs.cwd().realpathAlloc(arena_allocator, ".") catch |err| switch (err) {
            error.AccessDenied => try arena_allocator.dupe(u8, "/"),
            else => try arena_allocator.dupe(u8, "."),
        };
        try working_dir.appendSlice(cwd);

        const executor = try allocator.create(Self);
        executor.* = Self{
            .allocator = allocator,
            .arena = arena,
            .current_process = null,
            .working_directory = working_dir,
            .environment = env,
        };
        return executor;
    }

    /// Factory method for destroying executor capability
    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        // Clean up resources first
        self.deinit();
        // Then free the memory
        allocator.destroy(self);
    }

    /// ICapability interface implementation
    pub fn getName(self: *const Self) []const u8 {
        _ = self;
        return name;
    }

    pub fn getType(self: *const Self) []const u8 {
        _ = self;
        return capability_type;
    }

    pub fn getDependencies(self: *const Self) []const []const u8 {
        _ = self;
        return &[_][]const u8{}; // No dependencies
    }

    pub fn initialize(self: *Self, dependencies: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        _ = dependencies;
        self.event_bus = event_bus;
    }

    pub fn deinit(self: *Self) void {
        // Clean up resources when called by registry
        if (self.current_process) |*process| {
            _ = process.kill() catch {};
        }
        
        // Arena deinit frees all environment variables and working directory memory
        self.arena.deinit();
        self.allocator.destroy(self.arena);
        self.event_bus = null;
    }

    pub fn isActive(self: *const Self) bool {
        return self.event_bus != null;
    }

    /// Set output streaming callback
    pub fn setOutputCallback(self: *Self, callback: *const fn (context: *anyopaque, data: []const u8) anyerror!void, context: *anyopaque) void {
        self.output_callback = callback;
        self.output_context = context;
    }

    /// Execute a command and return result
    pub fn execute(self: *Self, command: []const u8, args: []const []const u8) !ProcessResult {
        // Build full argument list (command + args)
        var argv = std.ArrayList([]const u8).init(self.allocator);
        defer argv.deinit();
        
        try argv.append(command);
        try argv.appendSlice(args);

        // Create child process
        var child = std.process.Child.init(argv.items, self.allocator);
        child.cwd = self.working_directory.items;
        child.env_map = &self.environment;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        child.stdin_behavior = .Ignore;

        // Start the process
        try child.spawn();
        self.current_process = child;

        // Read output
        const stdout = try child.stdout.?.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB limit
        const stderr = try child.stderr.?.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB limit

        // Wait for completion
        const term = try child.wait();
        self.current_process = null;

        const exit_code: u8 = switch (term) {
            .Exited => |code| @as(u8, @truncate(code)),
            .Signal => 1,
            .Stopped => 1,
            .Unknown => 1,
        };

        // Stream output if callback is set
        if (self.output_callback) |callback| {
            if (stdout.len > 0) {
                try callback(self.output_context.?, stdout);
            }
            if (stderr.len > 0) {
                try callback(self.output_context.?, stderr);
            }
        }

        // Emit process completion event
        if (self.event_bus) |bus| {
            const event = kernel.Event.init(.state_change, .{
                .state_change = .{
                    .component = .executor,
                    .state = .{ .executor = .{ .exit_code = exit_code } },
                },
            });
            try bus.emit(event);
        }

        return ProcessResult{
            .stdout = stdout,
            .stderr = stderr,
            .exit_code = exit_code,
            .allocator = self.allocator,
        };
    }

    /// Execute command with shell (for more complex commands)
    pub fn executeShell(self: *Self, command_line: []const u8) !ProcessResult {
        const shell_cmd = "/bin/sh";
        const shell_args = [_][]const u8{ "-c", command_line };
        return self.execute(shell_cmd, &shell_args);
    }

    /// Change working directory
    pub fn changeDirectory(self: *Self, path: []const u8) !void {
        const arena_allocator = self.arena.allocator();
        
        // Resolve path using arena allocator
        const resolved_path = if (std.fs.path.isAbsolute(path))
            try arena_allocator.dupe(u8, path)
        else
            try std.fs.path.resolve(arena_allocator, &[_][]const u8{ self.working_directory.items, path });

        // Validate directory exists
        var dir = std.fs.cwd().openDir(resolved_path, .{}) catch |err| switch (err) {
            error.FileNotFound => return error.DirectoryNotFound,
            error.NotDir => return error.NotADirectory,
            error.AccessDenied => return error.PermissionDenied,
            else => return err,
        };
        dir.close();

        // Update working directory
        self.working_directory.clearRetainingCapacity();
        try self.working_directory.appendSlice(resolved_path);

        // Emit directory change event
        if (self.event_bus) |bus| {
            const event = kernel.Event.init(.state_change, .{
                .state_change = .{
                    .component = .executor,
                    .state = .{ .executor = .{ .exit_code = 0 } },
                },
            });
            try bus.emit(event);
        }
    }

    /// Get current working directory
    pub fn getCurrentDirectory(self: *const Self) []const u8 {
        return self.working_directory.items;
    }

    /// Set environment variable
    pub fn setEnvironmentVariable(self: *Self, var_name: []const u8, value: []const u8) !void {
        // EnvMap.put() handles memory management for us
        try self.environment.put(var_name, value);
    }

    /// Get environment variable
    pub fn getEnvironmentVariable(self: *const Self, var_name: []const u8) ?[]const u8 {
        return self.environment.get(var_name);
    }

    /// Get all environment variables
    pub fn getEnvironmentVariables(self: *const Self) std.process.EnvMap.Iterator {
        return self.environment.iterator();
    }

    /// Kill current running process
    pub fn killCurrentProcess(self: *Self) !void {
        if (self.current_process) |*process| {
            try process.kill();
            self.current_process = null;
        }
    }

    /// Check if a process is currently running
    pub fn isProcessRunning(self: *const Self) bool {
        return self.current_process != null;
    }
};

// Tests
test "Executor capability initialization" {
    const allocator = std.testing.allocator;
    var executor = try Executor.create(allocator);
    defer executor.destroy(allocator);

    try std.testing.expectEqualStrings("process_executor", executor.getName());
    try std.testing.expectEqualStrings("commands", executor.getType());
    try std.testing.expect(executor.getDependencies().len == 0);
    try std.testing.expect(!executor.isProcessRunning());
}

test "Executor simple command execution" {
    const allocator = std.testing.allocator;
    var executor = try Executor.create(allocator);
    defer executor.destroy(allocator);

    // Test echo command
    var result = executor.execute("echo", &[_][]const u8{"hello"}) catch |err| switch (err) {
        error.FileNotFound => {
            // echo might not be available in test environment
            return;
        },
        else => return err,
    };
    defer result.deinit();

    try std.testing.expect(result.exit_code == 0);
    try std.testing.expect(std.mem.startsWith(u8, result.stdout, "hello"));
}

test "Executor working directory operations" {
    const allocator = std.testing.allocator;
    var executor = try Executor.create(allocator);
    defer executor.destroy(allocator);

    const initial_dir = executor.getCurrentDirectory();
    try std.testing.expect(initial_dir.len > 0);

    // Test changing to root directory (should exist on all Unix systems)
    try executor.changeDirectory("/");
    try std.testing.expectEqualStrings("/", executor.getCurrentDirectory());
}

test "Executor environment variables" {
    const allocator = std.testing.allocator;
    var executor = try Executor.create(allocator);
    defer executor.destroy(allocator);

    // First check if we can access existing environment variables
    const path_var = executor.getEnvironmentVariable("PATH");
    try std.testing.expect(path_var != null);
    
    // Try setting a new environment variable
    try executor.setEnvironmentVariable("TEST_VAR", "test_value");
    
    const value = executor.getEnvironmentVariable("TEST_VAR");
    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("test_value", value.?);
}