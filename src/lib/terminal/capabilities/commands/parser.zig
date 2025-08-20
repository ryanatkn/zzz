const std = @import("std");
const kernel = @import("../../kernel/mod.zig");

/// Command line parser capability - handles argument parsing, quoting, and escaping
pub const Parser = struct {
    allocator: std.mem.Allocator,
    event_bus: ?*kernel.EventBus = null,

    const Self = @This();

    /// Parsed command result
    pub const ParseResult = struct {
        command: []const u8,
        args: [][]const u8,
        allocator: std.mem.Allocator,

        pub fn deinit(self: *ParseResult) void {
            // Free the args array and all argument strings
            for (self.args) |arg| {
                self.allocator.free(arg);
            }
            self.allocator.free(self.command);
            self.allocator.free(self.args);
        }
    };

    /// Factory method for creating parser capability
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const parser = try allocator.create(Self);
        parser.* = Self{
            .allocator = allocator,
        };
        return parser;
    }

    /// Factory method for destroying parser capability
    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    /// Get dependencies (none for parser)
    pub fn getDependencies(self: *const Self) []const []const u8 {
        _ = self;
        return &[_][]const u8{}; // No dependencies
    }

    pub fn initialize(self: *Self, dependencies: []const kernel.TypeSafeCapability, event_bus: *kernel.EventBus) !void {
        _ = dependencies;
        self.event_bus = event_bus;
    }

    pub fn deinit(self: *Self) void {
        self.event_bus = null;
    }

    pub fn isActive(self: *const Self) bool {
        return self.event_bus != null;
    }

    /// Parse command line into command and arguments
    pub fn parse(self: *Self, command_line: []const u8) !ParseResult {
        // Create arguments list
        var args = std.ArrayList([]const u8).init(self.allocator);
        errdefer {
            // Clean up on error only
            for (args.items) |arg| {
                self.allocator.free(arg);
            }
            args.deinit();
        }

        try self.parseArgs(command_line, &args);

        if (args.items.len == 0) {
            return error.EmptyCommand;
        }

        // Extract command and arguments
        const command = args.items[0];
        const command_args = if (args.items.len > 1) args.items[1..] else &[_][]const u8{};

        // Transfer ownership to result - duplicate the command string
        const owned_command = try self.allocator.dupe(u8, command);

        // Duplicate each argument string
        var owned_args = try self.allocator.alloc([]const u8, command_args.len);
        for (command_args, 0..) |arg, i| {
            owned_args[i] = try self.allocator.dupe(u8, arg);
        }

        // Clean up the temporary args since we've duplicated what we need
        for (args.items) |arg| {
            self.allocator.free(arg);
        }
        args.deinit();

        return ParseResult{
            .command = owned_command,
            .args = owned_args,
            .allocator = self.allocator,
        };
    }

    /// Parse command line into arguments with proper quoting support
    fn parseArgs(self: *Self, command_line: []const u8, args: *std.ArrayList([]const u8)) !void {
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
                        const next_ch = command_line[i];
                        switch (next_ch) {
                            'n' => try current_arg.append('\n'),
                            't' => try current_arg.append('\t'),
                            'r' => try current_arg.append('\r'),
                            '\\' => try current_arg.append('\\'),
                            '"' => try current_arg.append('"'),
                            '\'' => try current_arg.append('\''),
                            else => {
                                try current_arg.append('\\');
                                try current_arg.append(next_ch);
                            },
                        }
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

    /// Validate command line syntax (check for unclosed quotes, etc.)
    pub fn validate(self: *Self, command_line: []const u8) !void {
        _ = self;

        var in_quotes = false;
        var quote_char: u8 = 0;
        var escape_next = false;

        for (command_line) |ch| {
            if (escape_next) {
                escape_next = false;
                continue;
            }

            switch (ch) {
                '\\' => escape_next = true,
                '"', '\'' => {
                    if (in_quotes and ch == quote_char) {
                        in_quotes = false;
                        quote_char = 0;
                    } else if (!in_quotes) {
                        in_quotes = true;
                        quote_char = ch;
                    }
                },
                else => {},
            }
        }

        if (in_quotes) {
            return error.UnclosedQuote;
        }
        if (escape_next) {
            return error.TrailingEscape;
        }
    }
};

// Tests
test "Parser capability initialization" {
    const allocator = std.testing.allocator;
    var parser = try Parser.create(allocator);
    defer parser.destroy(allocator);

    // Test that capability can be created and has correct properties
    try std.testing.expect(parser.getDependencies().len == 0);

    // Test that capability starts inactive
    try std.testing.expect(!parser.isActive());

    // Test that allocator is properly set
    try std.testing.expect(parser.allocator.ptr == allocator.ptr);

    // Test that event bus is initially null
    try std.testing.expect(parser.event_bus == null);
}

test "Parser basic command parsing" {
    const allocator = std.testing.allocator;
    var parser = try Parser.create(allocator);
    defer parser.destroy(allocator);

    var result = try parser.parse("echo hello world");
    defer result.deinit();

    try std.testing.expectEqualStrings("echo", result.command);
    try std.testing.expect(result.args.len == 2);
    try std.testing.expectEqualStrings("hello", result.args[0]);
    try std.testing.expectEqualStrings("world", result.args[1]);
}

test "Parser quoted arguments" {
    const allocator = std.testing.allocator;
    var parser = try Parser.create(allocator);
    defer parser.destroy(allocator);

    var result = try parser.parse("echo \"hello world\" 'single quotes'");
    defer result.deinit();

    try std.testing.expectEqualStrings("echo", result.command);
    try std.testing.expect(result.args.len == 2);
    try std.testing.expectEqualStrings("hello world", result.args[0]);
    try std.testing.expectEqualStrings("single quotes", result.args[1]);
}

test "Parser escape sequences" {
    const allocator = std.testing.allocator;
    var parser = try Parser.create(allocator);
    defer parser.destroy(allocator);

    var result = try parser.parse("echo \"line1\\nline2\" tab\\tseparated");
    defer result.deinit();

    try std.testing.expectEqualStrings("echo", result.command);
    try std.testing.expect(result.args.len == 2);
    try std.testing.expectEqualStrings("line1\nline2", result.args[0]);
    try std.testing.expectEqualStrings("tab\tseparated", result.args[1]);
}

test "Parser empty command" {
    const allocator = std.testing.allocator;
    var parser = try Parser.create(allocator);
    defer parser.destroy(allocator);

    try std.testing.expectError(error.EmptyCommand, parser.parse(""));
    try std.testing.expectError(error.EmptyCommand, parser.parse("   "));
}

test "Parser validation errors" {
    const allocator = std.testing.allocator;
    var parser = try Parser.create(allocator);
    defer parser.destroy(allocator);

    try std.testing.expectError(error.UnclosedQuote, parser.validate("echo \"unclosed"));
    try std.testing.expectError(error.TrailingEscape, parser.validate("echo trailing\\"));

    // Valid cases should not error
    try parser.validate("echo \"valid\" command");
    try parser.validate("echo 'valid' command");
}
