const std = @import("std");
const core = @import("core.zig");
const scrollback_cap = @import("capabilities/state/scrollback.zig");

const Line = core.Line;
const RingBuffer = core.RingBuffer;
const VisibleLinesIterator = core.VisibleLinesIterator;
const ScrollbackCapability = scrollback_cap.Scrollback;

/// Terminal viewport manager for efficient visible line rendering
pub const TerminalViewport = struct {
    /// Get lines in rendering order (oldest first, newest last)
    /// This ensures when rendered top-to-bottom, newest lines appear at bottom
    pub fn getVisibleLinesArray(allocator: std.mem.Allocator, scrollback: *const RingBuffer(Line, 1000), max_rows: usize) ![]Line {
        var lines_list = std.ArrayList(Line).init(allocator);
        defer lines_list.deinit();

        var iterator = VisibleLinesIterator.init(scrollback, max_rows);
        while (iterator.next()) |line| {
            try lines_list.append(line);
        }

        return lines_list.toOwnedSlice();
    }

    /// Check if viewport should show scrollback indicator
    pub fn hasMoreScrollback(scrollback: *const RingBuffer(Line, 1000), max_rows: usize) bool {
        return scrollback.count() > max_rows;
    }

    /// Calculate total visible area height needed
    pub fn calculateRequiredHeight(line_count: usize, line_height: f32, line_spacing: f32) f32 {
        if (line_count == 0) return 0;
        return @as(f32, @floatFromInt(line_count)) * line_height + 
               @as(f32, @floatFromInt(line_count - 1)) * line_spacing;
    }

    /// Calculate maximum lines that fit in available height
    pub fn calculateMaxLines(available_height: f32, line_height: f32, line_spacing: f32) usize {
        if (available_height <= 0 or line_height <= 0) return 0;
        
        // Account for spacing between lines
        const effective_line_height = line_height + line_spacing;
        const max_lines = @as(usize, @intFromFloat(available_height / effective_line_height));
        
        return @max(1, max_lines);
    }

};

// TODO: Add line wrapping support
// TODO: Add search highlighting support  
// TODO: Add selection support