const std = @import("std");
const loggers = @import("../debug/loggers.zig");
const builtin = @import("builtin");

/// Process execution result
pub const ProcessResult = struct {
    stdout: []u8,
    stderr: []u8,
    exit_code: u8,

    pub fn deinit(self: *ProcessResult, allocator: std.mem.Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
    }
};

/// Process executor for terminal commands
pub const ProcessExecutor = struct {
    allocator: std.mem.Allocator,
    current_process: ?std.process.Child = null,
    working_directory: std.ArrayList(u8),
    environment: std.process.EnvMap,

    // Output streaming callback
    output_callback: ?*const fn (context: *anyopaque, data: []const u8) anyerror!void = null,
    output_context: ?*anyopaque = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        var env = std.process.EnvMap.init(allocator);

        // Copy current environment
        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();
        var env_iter = env_map.iterator();
        while (env_iter.next()) |entry| {
            try env.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        // Get initial working directory
        var working_dir = std.ArrayList(u8).init(allocator);
        const cwd = std.fs.cwd().realpathAlloc(allocator, ".") catch |err| switch (err) {
            error.AccessDenied => try allocator.dupe(u8, "/"),
            else => try allocator.dupe(u8, "."),
        };
        try working_dir.appendSlice(cwd);
        allocator.free(cwd);

        return Self{
            .allocator = allocator,
            .working_directory = working_dir,
            .environment = env,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.current_process) |*process| {
            const term = process.kill() catch |err| {
                std.log.err("Failed to kill process during deinit: {}", .{err});
                return;
            };
            std.log.debug("Process killed with term: {}", .{term});
        }
        self.working_directory.deinit();
        self.environment.deinit();
    }

    /// Execute a command and return the result
    pub fn execute(self: *Self, command_line: []const u8) !ProcessResult {
        // Parse command line into arguments
        var args = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (args.items) |arg| {
                self.allocator.free(arg);
            }
            args.deinit();
        }

        try self.parseCommandLine(command_line, &args);

        if (args.items.len == 0) {
            return ProcessResult{
                .stdout = try self.allocator.dupe(u8, ""),
                .stderr = try self.allocator.dupe(u8, ""),
                .exit_code = 0,
            };
        }

        // Set up process
        var process = std.process.Child.init(args.items, self.allocator);
        process.cwd = self.working_directory.items;
        process.env_map = &self.environment;
        process.stdout_behavior = .Pipe;
        process.stderr_behavior = .Pipe;
        process.stdin_behavior = .Close;

        // Spawn process
        try process.spawn();
        self.current_process = process;

        // Read output
        const stdout = try process.stdout.?.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB max
        const stderr = try process.stderr.?.readToEndAlloc(self.allocator, 1024 * 1024);

        // Wait for completion
        const result = try process.wait();
        self.current_process = null;

        const exit_code: u8 = switch (result) {
            .Exited => |code| @intCast(code),
            .Signal => 128, // Terminated by signal
            .Stopped => 129, // Process stopped
            .Unknown => 130, // Unknown termination
        };

        return ProcessResult{
            .stdout = stdout,
            .stderr = stderr,
            .exit_code = exit_code,
        };
    }

    /// Execute a command asynchronously (for interactive commands)
    pub fn executeAsync(self: *Self, command_line: []const u8) !void {
        // Kill existing process if running
        if (self.current_process) |*process| {
            const term = process.kill() catch |err| {
                std.log.err("Failed to kill existing process: {}", .{err});
                return;
            };
            std.log.debug("Process killed with term: {}", .{term});
        }

        // Parse command line
        var args = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (args.items) |arg| {
                self.allocator.free(arg);
            }
            args.deinit();
        }

        try self.parseCommandLine(command_line, &args);

        if (args.items.len == 0) return;

        // Set up process
        var process = std.process.Child.init(args.items, self.allocator);
        process.cwd = self.working_directory.items;
        process.env_map = &self.environment;
        process.stdout_behavior = .Pipe;
        process.stderr_behavior = .Pipe;
        process.stdin_behavior = .Pipe;

        // Spawn process
        try process.spawn();
        self.current_process = process;
    }

    /// Check if process is running
    pub fn isProcessRunning(self: *const Self) bool {
        return self.current_process != null;
    }

    /// Read output from running process (non-blocking)
    pub fn readProcessOutput(self: *Self) !?[]u8 {
        if (self.current_process) |*process| {
            if (process.stdout) |stdout| {
                // Try to read available data
                var buffer: [4096]u8 = undefined;
                const bytes_read = stdout.read(&buffer) catch |err| switch (err) {
                    error.WouldBlock => return null, // No data available
                    else => return err,
                };

                if (bytes_read == 0) return null;
                return try self.allocator.dupe(u8, buffer[0..bytes_read]);
            }
        }
        return null;
    }

    /// Send input to running process
    pub fn writeProcessInput(self: *Self, input: []const u8) !void {
        if (self.current_process) |*process| {
            if (process.stdin) |stdin| {
                try stdin.writeAll(input);
            }
        }
    }

    /// Kill running process
    pub fn killProcess(self: *Self) !void {
        if (self.current_process) |*process| {
            try process.kill();
            _ = try process.wait();
            self.current_process = null;
        }
    }

    /// Send signal to running process
    pub fn sendSignal(self: *Self, signal: std.posix.SIG) !void {
        if (self.current_process) |*process| {
            try std.posix.kill(process.id, signal);
        }
    }

    /// Change working directory
    pub fn changeDirectory(self: *Self, path: []const u8) !void {
        // Resolve path
        const resolved_path = if (std.fs.path.isAbsolute(path))
            try self.allocator.dupe(u8, path)
        else blk: {
            const full_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.working_directory.items, path });
            defer self.allocator.free(full_path);
            break :blk try std.fs.cwd().realpathAlloc(self.allocator, full_path);
        };
        defer self.allocator.free(resolved_path);

        // Verify directory exists
        var dir = std.fs.openDirAbsolute(resolved_path, .{}) catch |err| switch (err) {
            error.FileNotFound => return error.DirectoryNotFound,
            error.NotDir => return error.NotADirectory,
            else => return err,
        };
        dir.close();

        // Update working directory
        self.working_directory.clearRetainingCapacity();
        try self.working_directory.appendSlice(resolved_path);

        // Update PWD environment variable
        try self.environment.put("PWD", self.working_directory.items);
    }

    /// Get current working directory
    pub fn getWorkingDirectory(self: *const Self) []const u8 {
        return self.working_directory.items;
    }

    /// Set environment variable
    pub fn setEnv(self: *Self, key: []const u8, value: []const u8) !void {
        try self.environment.put(key, value);
    }

    /// Get environment variable
    pub fn getEnv(self: *const Self, key: []const u8) ?[]const u8 {
        return self.environment.get(key);
    }

    /// Parse command line into arguments (simple shell-like parsing)
    pub fn parseCommandLine(self: *Self, command_line: []const u8, args: *std.ArrayList([]const u8)) !void {
        var i: usize = 0;
        var in_quotes = false;
        var quote_char: u8 = 0;
        var current_arg = std.ArrayList(u8).init(self.allocator);

        while (i < command_line.len) {
            const ch = command_line[i];

            switch (ch) {
                ' ', '\t' => {
                    if (in_quotes) {
                        try current_arg.append(ch);
                    } else if (current_arg.items.len > 0) {
                        try args.append(try current_arg.toOwnedSlice());
                        current_arg = std.ArrayList(u8).init(self.allocator);
                    }
                },
                '"', '\'' => {
                    if (in_quotes and ch == quote_char) {
                        in_quotes = false;
                        quote_char = 0;
                    } else if (!in_quotes) {
                        in_quotes = true;
                        quote_char = ch;
                    } else {
                        try current_arg.append(ch);
                    }
                },
                '\\' => {
                    if (i + 1 < command_line.len) {
                        i += 1;
                        try current_arg.append(command_line[i]);
                    } else {
                        try current_arg.append(ch);
                    }
                },
                else => {
                    try current_arg.append(ch);
                },
            }

            i += 1;
        }

        // Add final argument if any
        if (current_arg.items.len > 0) {
            try args.append(try current_arg.toOwnedSlice());
        } else {
            current_arg.deinit();
        }
    }

    /// Check if a command exists in PATH
    pub fn commandExists(self: *Self, command: []const u8) bool {
        // Check if it's an absolute or relative path
        if (std.mem.indexOf(u8, command, "/") != null) {
            std.fs.cwd().access(command, .{}) catch {
                return false;
            };
            return true;
        }

        // Search in PATH
        const path_env = self.environment.get("PATH") orelse std.posix.getenv("PATH") orelse {
            return false;
        };

        var path_iter = std.mem.splitScalar(u8, path_env, ':');

        while (path_iter.next()) |path_dir| {
            if (path_dir.len == 0) continue;

            var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
            const full_path = std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ path_dir, command }) catch {
                continue;
            };

            std.fs.cwd().access(full_path, .{}) catch {
                continue;
            };

            return true;
        }

        return false;
    }

    /// Set output streaming callback
    pub fn setOutputCallback(self: *Self, callback: *const fn (context: *anyopaque, data: []const u8) anyerror!void, context: *anyopaque) void {
        self.output_callback = callback;
        self.output_context = context;
    }

    /// Execute with streaming output
    pub fn executeWithStreaming(self: *Self, command_line: []const u8) !ProcessResult {
        // Parse command line into arguments
        var args = std.ArrayList([]const u8).init(self.allocator);
        defer {
            for (args.items) |arg| {
                self.allocator.free(arg);
            }
            args.deinit();
        }

        try self.parseCommandLine(command_line, &args);

        if (args.items.len == 0) {
            return ProcessResult{
                .stdout = try self.allocator.dupe(u8, ""),
                .stderr = try self.allocator.dupe(u8, ""),
                .exit_code = 0,
            };
        }

        // Set up process
        var process = std.process.Child.init(args.items, self.allocator);
        process.cwd = self.working_directory.items;
        process.env_map = &self.environment;
        process.stdout_behavior = .Pipe;
        process.stderr_behavior = .Pipe;
        process.stdin_behavior = .Close;

        // Spawn process with comprehensive error handling
        process.spawn() catch |err| {
            // Only log errors using game logger
            const error_msg = switch (err) {
                error.FileNotFound => blk: {
                    if (self.commandExists(args.items[0])) {
                        break :blk "Command found in PATH but spawn failed - permission issue?";
                    } else {
                        break :blk "Command not found in PATH";
                    }
                },
                error.AccessDenied => "Permission denied - cannot execute command",
                error.SystemResources => "System resources exhausted",
                error.InvalidExe => "Invalid executable format",
                else => "Unknown spawn error",
            };

            if (loggers.game_log) |*log| {
                log.warn("terminal_spawn", "Process spawn failed: {s} for command: {s}", .{ error_msg, args.items[0] });
            }

            // Return error result instead of crashing
            return ProcessResult{
                .stdout = try self.allocator.dupe(u8, ""),
                .stderr = try self.allocator.dupe(u8, error_msg),
                .exit_code = 127, // Standard "command not found" exit code
            };
        };
        self.current_process = process;

        // Read output with streaming if callback is set
        var stdout_data = std.ArrayList(u8).init(self.allocator);
        var stderr_data = std.ArrayList(u8).init(self.allocator);
        defer stdout_data.deinit();
        defer stderr_data.deinit();

        if (self.output_callback) |callback| {
            if (self.output_context) |context| {
                // Stream output in real-time
                try self.streamOutput(process.stdout.?, &stdout_data, callback, context);
                try self.streamOutput(process.stderr.?, &stderr_data, callback, context);
            }
        } else {
            // Fallback to regular reading
            const stdout = try process.stdout.?.readToEndAlloc(self.allocator, 1024 * 1024);
            const stderr = try process.stderr.?.readToEndAlloc(self.allocator, 1024 * 1024);
            defer self.allocator.free(stdout);
            defer self.allocator.free(stderr);

            try stdout_data.appendSlice(stdout);
            try stderr_data.appendSlice(stderr);
        }

        // Wait for completion
        const result = try process.wait();
        self.current_process = null;

        const exit_code: u8 = switch (result) {
            .Exited => |code| @intCast(code),
            .Signal => 128,
            .Stopped => 129,
            .Unknown => 130,
        };

        return ProcessResult{
            .stdout = try stdout_data.toOwnedSlice(),
            .stderr = try stderr_data.toOwnedSlice(),
            .exit_code = exit_code,
        };
    }

    /// Stream output from a file descriptor
    fn streamOutput(
        self: *Self,
        stream: std.fs.File,
        buffer: *std.ArrayList(u8),
        callback: *const fn (context: *anyopaque, data: []const u8) anyerror!void,
        callback_context: *anyopaque,
    ) !void {
        _ = self;
        var read_buffer: [4096]u8 = undefined;

        while (true) {
            const bytes_read = stream.read(&read_buffer) catch |err| switch (err) {
                error.WouldBlock => break, // No more data available
                else => return err,
            };

            if (bytes_read == 0) break; // EOF

            const data = read_buffer[0..bytes_read];

            // Send to callback for real-time display
            try callback(callback_context, data);

            // Also store in buffer for final result
            try buffer.appendSlice(data);
        }
    }

    /// Get shell for current platform
    pub fn getDefaultShell() []const u8 {
        return switch (builtin.target.os.tag) {
            .windows => "cmd.exe",
            else => "/bin/sh",
        };
    }
};
