const std = @import("std");
const builtin = @import("builtin");
const c = @import("../../platform/sdl.zig");
const input = @import("../../platform/input.zig");
const math = @import("../../math/mod.zig");
const loggers = @import("../../debug/loggers.zig");

const Vec2 = math.Vec2;

/// Lock-free ring buffer for AI input commands
/// Designed for memory-mapped shared access between AI and game
pub const DirectInputBuffer = extern struct {
    /// Magic number for validation (0xA1C0DE42)
    magic: u32 = 0xA1C0DE42,

    /// Version for compatibility checking
    version: u32 = 1,

    /// Write index (updated atomically by writer)
    write_index: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),

    /// Read index (updated by reader only)
    read_index: u32 = 0,

    /// Current frame number from game
    current_frame: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),

    /// Fixed-size ring buffer of commands
    commands: [BUFFER_SIZE]InputCommand = [_]InputCommand{InputCommand.empty()} ** BUFFER_SIZE,

    pub const BUFFER_SIZE = 256;

    /// Single input command (24 bytes with padding, cache-line friendly)
    pub const InputCommand = extern struct {
        /// Target frame number (0 = immediate)
        frame: u32,

        /// First 64 keyboard keys as bitfield
        keys_down: u64,

        /// Mouse X position (screen coordinates)
        mouse_x: f32,

        /// Mouse Y position (screen coordinates)
        mouse_y: f32,

        /// Mouse buttons and flags
        /// Bit 0: Left mouse
        /// Bit 1: Right mouse
        /// Bit 2: Middle mouse
        /// Bit 7: Valid command flag
        buttons: u8,

        /// Alignment padding
        _padding: [3]u8 = .{ 0, 0, 0 },

        pub fn empty() InputCommand {
            return .{
                .frame = 0,
                .keys_down = 0,
                .mouse_x = 0,
                .mouse_y = 0,
                .buttons = 0,
                ._padding = .{ 0, 0, 0 },
            };
        }

        pub fn isValid(self: InputCommand) bool {
            return (self.buttons & 0x80) != 0;
        }

        pub fn setValid(self: *InputCommand) void {
            self.buttons |= 0x80;
        }

        pub fn debugLayout() void {
            loggers.getGameLog().info("ai_layout", "InputCommand layout: size={}, frame@{}, keys@{}, mouse_x@{}, mouse_y@{}, buttons@{}, padding@{}", .{ @sizeOf(InputCommand), @offsetOf(InputCommand, "frame"), @offsetOf(InputCommand, "keys_down"), @offsetOf(InputCommand, "mouse_x"), @offsetOf(InputCommand, "mouse_y"), @offsetOf(InputCommand, "buttons"), @offsetOf(InputCommand, "_padding") });
        }
    };

    /// Initialize a new buffer
    pub fn init() DirectInputBuffer {
        return .{};
    }

    /// Check if buffer is valid
    pub fn isValid(self: *const DirectInputBuffer) bool {
        return self.magic == 0xA1C0DE42 and self.version == 1;
    }

    /// Writer: Add a command to the buffer (lock-free)
    pub fn writeCommand(self: *DirectInputBuffer, cmd: InputCommand) bool {
        const write_pos = self.write_index.load(.monotonic);
        const read_pos = @atomicLoad(u32, &self.read_index, .monotonic);

        // Check if buffer is full (leave one slot empty to distinguish full/empty)
        const next_write = (write_pos + 1) % BUFFER_SIZE;
        if (next_write == read_pos) {
            return false; // Buffer full
        }

        // Write command
        self.commands[write_pos] = cmd;

        // Update write index atomically
        _ = self.write_index.store(next_write, .release);

        return true;
    }

    /// Reader: Get next command from buffer (single reader)
    pub fn readCommand(self: *DirectInputBuffer) ?InputCommand {
        const read_pos = self.read_index;
        const write_pos = self.write_index.load(.acquire);

        // Check if buffer is empty
        if (read_pos == write_pos) {
            return null;
        }

        // Read command
        const cmd = self.commands[read_pos];

        // Update read index (single reader, no atomics needed)
        self.read_index = (read_pos + 1) % BUFFER_SIZE;

        return cmd;
    }

    /// Reader: Peek at next command without consuming
    pub fn peekCommand(self: *const DirectInputBuffer) ?InputCommand {
        const read_pos = @atomicLoad(u32, &self.read_index, .monotonic);
        const write_pos = self.write_index.load(.acquire);

        if (read_pos == write_pos) {
            return null;
        }

        return self.commands[read_pos];
    }

    /// Update current frame number (called by game)
    pub fn setCurrentFrame(self: *DirectInputBuffer, frame: u32) void {
        _ = self.current_frame.store(frame, .release);
    }

    /// Get current frame number (for AI to read)
    pub fn getCurrentFrame(self: *const DirectInputBuffer) u32 {
        return self.current_frame.load(.acquire);
    }

    /// Clear all pending commands
    pub fn clear(self: *DirectInputBuffer) void {
        self.read_index = self.write_index.load(.monotonic);
    }

    /// Get number of pending commands
    pub fn pending(self: *const DirectInputBuffer) u32 {
        const read_pos = @atomicLoad(u32, &self.read_index, .monotonic);
        const write_pos = self.write_index.load(.acquire);

        if (write_pos >= read_pos) {
            return write_pos - read_pos;
        } else {
            return BUFFER_SIZE - read_pos + write_pos;
        }
    }
};

/// Apply command to input state
pub fn applyCommand(cmd: DirectInputBuffer.InputCommand, state: *input.InputState) void {

    // Log raw command bytes for debugging
    const cmd_bytes = @as([*]const u8, @ptrCast(&cmd))[0..@sizeOf(DirectInputBuffer.InputCommand)];
    loggers.getGameLog().debug("ai_raw_cmd", "Raw command bytes: {}", .{std.fmt.fmtSliceHexLower(cmd_bytes)});
    loggers.getGameLog().debug("ai_cmd_fields", "Command fields: frame={}, keys=0x{x:0>16}, mouse=({d:.1},{d:.1}), buttons=0x{x:0>2}", .{ cmd.frame, cmd.keys_down, cmd.mouse_x, cmd.mouse_y, cmd.buttons });

    // Skip invalid commands
    if (!cmd.isValid()) {
        loggers.getGameLog().warn("ai_invalid_cmd", "Skipping invalid command: buttons=0x{x:0>2} (need 0x80 flag)", .{cmd.buttons});
        return;
    }

    // Apply mouse position
    state.mouse_pos.x = cmd.mouse_x;
    state.mouse_pos.y = cmd.mouse_y;

    // Apply mouse buttons
    state.left_mouse_held = (cmd.buttons & 0x01) != 0;
    state.right_mouse_held = (cmd.buttons & 0x02) != 0;

    // Apply keyboard keys (first 64 scancodes)
    state.keys_down = std.StaticBitSet(512).initEmpty();
    var i: u32 = 0;
    while (i < 64) : (i += 1) {
        if (cmd.keys_down & (@as(u64, 1) << @intCast(i)) != 0) {
            state.keys_down.set(@intCast(i));
        }
    }
}

/// Process all pending commands for the current frame
pub fn processCommands(buffer: *DirectInputBuffer, state: *input.InputState, current_frame: u32) void {

    // Update frame counter in buffer
    buffer.setCurrentFrame(current_frame);

    var commands_processed: u32 = 0;

    // Process all commands for current or past frames
    while (buffer.peekCommand()) |cmd| {
        // Accept immediate commands (frame=0) or commands for current/past frames
        // Also handle corrupted frame numbers by processing them as immediate
        const should_process = cmd.frame == 0 or cmd.frame <= current_frame or cmd.frame > 1000000; // Treat large corrupt values as immediate

        if (should_process) {
            // Apply this command
            if (buffer.readCommand()) |actual_cmd| {
                if (actual_cmd.frame > 1000000) {
                    loggers.getGameLog().warn("ai_corrupt_frame", "Processing command with corrupted frame {}, treating as immediate", .{actual_cmd.frame});
                }
                loggers.getGameLog().debug("ai_apply_cmd", "Applying command: frame={}, buttons=0x{x:0>2}, keys=0x{x:0>16}, mouse=({d:.0},{d:.0})", .{ actual_cmd.frame, actual_cmd.buttons, actual_cmd.keys_down, actual_cmd.mouse_x, actual_cmd.mouse_y });
                applyCommand(actual_cmd, state);
                commands_processed += 1;
            }
        } else {
            // Future command, stop processing
            loggers.getGameLog().debug("ai_future_cmd", "Stopping at future command: frame={} > current={}", .{ cmd.frame, current_frame });
            break;
        }
    }

    if (commands_processed > 0) {
        loggers.getGameLog().info("ai_cmds_done", "Processed {} commands, buffer state: read={}, pending={}", .{ commands_processed, buffer.read_index, buffer.pending() });
    }
}

/// Memory-mapped file interface
pub const MappedInput = struct {
    file: std.fs.File,
    mapping: []align(4096) u8, // Standard page size
    buffer: *DirectInputBuffer,

    pub fn init(path: []const u8) !MappedInput {
        const file = try std.fs.cwd().createFile(path, .{
            .read = true,
            .truncate = false,
        });
        errdefer file.close();

        // Ensure file is correct size
        const buffer_size = @sizeOf(DirectInputBuffer);
        try file.setEndPos(buffer_size);

        // Memory map the file
        const mapping = try std.posix.mmap(
            null,
            buffer_size,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{ .TYPE = .SHARED },
            file.handle,
            0,
        );
        errdefer std.posix.munmap(mapping);

        // Cast to our buffer type
        const buffer = @as(*DirectInputBuffer, @ptrCast(@alignCast(mapping.ptr)));

        // Initialize if new file
        if (!buffer.isValid()) {
            buffer.* = DirectInputBuffer.init();
        }

        return .{
            .file = file,
            .mapping = mapping,
            .buffer = buffer,
        };
    }

    pub fn deinit(self: *MappedInput) void {
        std.posix.munmap(self.mapping);
        self.file.close();
    }
};

// Testing helper
test "DirectInputBuffer basic operations" {
    var buffer = DirectInputBuffer.init();

    // Test empty buffer
    try std.testing.expect(buffer.pending() == 0);
    try std.testing.expect(buffer.readCommand() == null);

    // Test write and read
    var cmd = DirectInputBuffer.InputCommand.empty();
    cmd.mouse_x = 100;
    cmd.mouse_y = 200;
    cmd.setValid();

    try std.testing.expect(buffer.writeCommand(cmd));
    try std.testing.expect(buffer.pending() == 1);

    const read_cmd = buffer.readCommand();
    try std.testing.expect(read_cmd != null);
    try std.testing.expect(read_cmd.?.mouse_x == 100);
    try std.testing.expect(read_cmd.?.mouse_y == 200);

    // Buffer should be empty again
    try std.testing.expect(buffer.pending() == 0);
}
