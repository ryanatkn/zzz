const std = @import("std");
const core = @import("core.zig");

const Key = core.Key;

/// Process control for signal handling and job management
pub const ProcessControl = struct {
    allocator: std.mem.Allocator,
    interrupt_requested: bool = false,
    current_signal: ?u8 = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Request interrupt (Ctrl+C equivalent)
    pub fn requestInterrupt(self: *Self) void {
        self.interrupt_requested = true;
        self.current_signal = 2; // SIGINT
    }

    /// Check if interrupt was requested
    pub fn isInterruptRequested(self: *const Self) bool {
        return self.interrupt_requested;
    }

    /// Clear interrupt request
    pub fn clearInterrupt(self: *Self) void {
        self.interrupt_requested = false;
        self.current_signal = null;
    }

    /// Send signal to process
    pub fn sendSignalToProcess(self: *Self, process: *std.process.Child, signal: u8) !void {
        _ = self;
        try std.posix.kill(process.id, signal);
    }

    /// Handle Ctrl+C key combination
    pub fn handleCtrlC(self: *Self) void {
        self.requestInterrupt();
    }

    /// Check if process should be interrupted
    pub fn shouldInterruptProcess(self: *Self) bool {
        return self.isInterruptRequested();
    }

    /// Get current signal to send
    pub fn getCurrentSignal(self: *const Self) ?u8 {
        return self.current_signal;
    }
};

/// Signal handler for terminal key combinations
pub const SignalHandler = struct {
    process_control: *ProcessControl,

    const Self = @This();

    pub fn init(process_control: *ProcessControl) Self {
        return Self{
            .process_control = process_control,
        };
    }

    /// Handle keyboard input for signal generation
    pub fn handleKeyInput(self: *Self, key: Key) bool {
        switch (key) {
            .ctrl_c => {
                self.process_control.handleCtrlC();
                return true;
            },
            else => return false,
        }
    }

    /// Check if signal needs to be sent to current process
    pub fn processSignals(self: *Self, current_process: ?*std.process.Child) !bool {
        if (self.process_control.shouldInterruptProcess()) {
            if (current_process) |process| {
                if (self.process_control.getCurrentSignal()) |signal| {
                    try self.process_control.sendSignalToProcess(process, signal);
                    self.process_control.clearInterrupt();
                    return true; // Signal was sent
                }
            }
            // Clear interrupt even if no process to send to
            self.process_control.clearInterrupt();
        }
        return false;
    }
};
