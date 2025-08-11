const std = @import("std");

const MAX_HISTORY = 50;
const MAX_PATH_LEN = 256;

pub const SimpleHistory = struct {
    // Fixed-size buffers for paths
    paths: [MAX_HISTORY][MAX_PATH_LEN]u8,
    path_lens: [MAX_HISTORY]usize,
    stack_size: usize,
    current_index: usize,

    pub fn init() SimpleHistory {
        var hist = SimpleHistory{
            .paths = undefined,
            .path_lens = undefined,
            .stack_size = 1,
            .current_index = 0,
        };
        
        // Initialize with root path
        hist.paths[0][0] = '/';
        hist.path_lens[0] = 1;
        
        return hist;
    }

    pub fn navigate(self: *SimpleHistory, path: []const u8) !void {
        if (path.len >= MAX_PATH_LEN) return error.PathTooLong;
        
        // Remove any forward history
        self.stack_size = self.current_index + 1;
        
        // Don't add if it's the same as current
        if (self.stack_size > 0) {
            const current = self.getCurrentPath();
            if (std.mem.eql(u8, current, path)) return;
        }
        
        // Add new path
        if (self.stack_size >= MAX_HISTORY) {
            // Shift everything down
            for (1..MAX_HISTORY) |i| {
                @memcpy(&self.paths[i-1], &self.paths[i]);
                self.path_lens[i-1] = self.path_lens[i];
            }
            self.stack_size = MAX_HISTORY - 1;
            self.current_index = self.stack_size;
        }
        
        const idx = self.stack_size;
        @memcpy(self.paths[idx][0..path.len], path);
        self.path_lens[idx] = path.len;
        self.stack_size += 1;
        self.current_index = idx;
    }

    pub fn back(self: *SimpleHistory) bool {
        if (self.current_index > 0) {
            self.current_index -= 1;
            return true;
        }
        return false;
    }

    pub fn forward(self: *SimpleHistory) bool {
        if (self.current_index < self.stack_size - 1) {
            self.current_index += 1;
            return true;
        }
        return false;
    }

    pub fn getCurrentPath(self: *const SimpleHistory) []const u8 {
        const len = self.path_lens[self.current_index];
        return self.paths[self.current_index][0..len];
    }
};