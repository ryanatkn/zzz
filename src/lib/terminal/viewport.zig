const std = @import("std");
const core = @import("core.zig");
const scrollback_cap = @import("capabilities/state/scrollback.zig");

const Line = core.Line;
const RingBuffer = core.RingBuffer;
const VisibleLinesIterator = core.VisibleLinesIterator;
const ScrollbackCapability = scrollback_cap.Scrollback;

/// Terminal viewport manager for efficient visible line rendering
pub const TerminalViewport = struct {
    /// Maximum visible lines in a terminal viewport (reasonable upper limit)
    pub const MAX_VISIBLE_LINES = 256;
    
    /// Get lines in rendering order using bounded array for better performance
    /// This ensures when rendered top-to-bottom, newest lines appear at bottom
    /// Returns owned slice that must be freed by caller
    pub fn getVisibleLinesArray(allocator: std.mem.Allocator, scrollback: *const RingBuffer(Line, 1000), max_rows: usize) ![]Line {
        var lines_buffer = std.BoundedArray(Line, MAX_VISIBLE_LINES){};
        
        var iterator = VisibleLinesIterator.init(scrollback, @min(max_rows, MAX_VISIBLE_LINES));
        while (iterator.next()) |line| {
            lines_buffer.append(line) catch break; // Stop if buffer full
        }

        // Create owned slice for compatibility with existing API
        const result = try allocator.dupe(Line, lines_buffer.slice());
        return result;
    }
    
    /// Get visible lines without allocation using caller-provided buffer
    /// More efficient version for performance-critical code
    pub fn getVisibleLinesIntoBuffer(scrollback: *const RingBuffer(Line, 1000), max_rows: usize, buffer: []Line) usize {
        var count: usize = 0;
        var iterator = VisibleLinesIterator.init(scrollback, @min(max_rows, buffer.len));
        
        while (iterator.next()) |line| {
            if (count >= buffer.len) break;
            buffer[count] = line;
            count += 1;
        }
        
        return count;
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