const std = @import("std");
const math = @import("../math/mod.zig");

const Vec2 = math.Vec2;

/// File type classification for UI rendering and behavior
pub const FileType = enum {
    directory,
    zig_source,
    markdown,
    shader_hlsl,
    config_zon,
    text_file,
    unknown,
    
    /// Determine file type from file extension
    pub fn fromExtension(extension: []const u8) FileType {
        if (std.mem.eql(u8, extension, ".zig")) return .zig_source;
        if (std.mem.eql(u8, extension, ".md")) return .markdown;
        if (std.mem.eql(u8, extension, ".hlsl")) return .shader_hlsl;
        if (std.mem.eql(u8, extension, ".zon")) return .config_zon;
        if (std.mem.eql(u8, extension, ".txt")) return .text_file;
        return .unknown;
    }
    
    /// Get display name for file type
    pub fn getDisplayName(self: FileType) []const u8 {
        return switch (self) {
            .directory => "Folder",
            .zig_source => "Zig Source",
            .markdown => "Markdown",
            .shader_hlsl => "HLSL Shader",
            .config_zon => "Zig Config",
            .text_file => "Text File",
            .unknown => "File",
        };
    }
    
    /// Get color for file type (RGB values 0-255)
    pub fn getColor(self: FileType) struct { r: u8, g: u8, b: u8 } {
        return switch (self) {
            .directory => .{ .r = 100, .g = 149, .b = 237 }, // Blue
            .zig_source => .{ .r = 255, .g = 140, .b = 0 },   // Orange
            .markdown => .{ .r = 50, .g = 205, .b = 50 },     // Green
            .shader_hlsl => .{ .r = 255, .g = 20, .b = 147 }, // Pink
            .config_zon => .{ .r = 255, .g = 215, .b = 0 },   // Gold
            .text_file => .{ .r = 169, .g = 169, .b = 169 },  // Gray
            .unknown => .{ .r = 128, .g = 128, .b = 128 },    // Dark Gray
        };
    }
};

/// File metadata for display
pub const FileMetadata = struct {
    name: []const u8,
    full_path: []const u8,
    file_type: FileType,
    size: u64,
    is_directory: bool,
    modification_time: i128, // nanoseconds since epoch
    
    /// Create metadata for a file/directory
    pub fn create(allocator: std.mem.Allocator, name: []const u8, full_path: []const u8, stat: std.fs.File.Stat) !FileMetadata {
        const owned_name = try allocator.dupe(u8, name);
        const owned_path = try allocator.dupe(u8, full_path);
        
        const is_dir = stat.kind == .directory;
        const file_type = if (is_dir) FileType.directory else blk: {
            const ext = std.fs.path.extension(name);
            break :blk FileType.fromExtension(ext);
        };
        
        return FileMetadata{
            .name = owned_name,
            .full_path = owned_path,
            .file_type = file_type,
            .size = stat.size,
            .is_directory = is_dir,
            .modification_time = stat.mtime,
        };
    }
    
    /// Free allocated memory
    pub fn deinit(self: *FileMetadata, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.full_path);
    }
};

/// Directory entry for tree structure
pub const DirectoryEntry = struct {
    metadata: FileMetadata,
    children: std.ArrayList(*DirectoryEntry),
    parent: ?*DirectoryEntry,
    expanded: bool,
    
    const Self = @This();
    
    /// Create a new directory entry
    pub fn create(allocator: std.mem.Allocator, metadata: FileMetadata) !*DirectoryEntry {
        const entry = try allocator.create(DirectoryEntry);
        entry.* = DirectoryEntry{
            .metadata = metadata,
            .children = std.ArrayList(*DirectoryEntry).init(allocator),
            .parent = null,
            .expanded = false,
        };
        return entry;
    }
    
    /// Free entry and all children recursively
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        // Free children first
        for (self.children.items) |child| {
            child.deinit(allocator);
        }
        self.children.deinit();
        
        // Free metadata
        var metadata_copy = self.metadata;
        metadata_copy.deinit(allocator);
        
        // Free self
        allocator.destroy(self);
    }
    
    /// Add child entry and set parent relationship
    pub fn addChild(self: *Self, child: *DirectoryEntry) !void {
        child.parent = self;
        try self.children.append(child);
    }
    
    /// Sort children by type (directories first) then alphabetically
    pub fn sortChildren(self: *Self) void {
        const SortContext = struct {
            fn lessThan(context: void, a: *DirectoryEntry, b: *DirectoryEntry) bool {
                _ = context;
                // Directories come first
                if (a.metadata.is_directory and !b.metadata.is_directory) return true;
                if (!a.metadata.is_directory and b.metadata.is_directory) return false;
                
                // Then alphabetical
                return std.mem.lessThan(u8, a.metadata.name, b.metadata.name);
            }
        };
        
        std.mem.sort(*DirectoryEntry, self.children.items, {}, SortContext.lessThan);
    }
};

/// Directory scanner for filesystem traversal
pub const DirectoryScanner = struct {
    allocator: std.mem.Allocator,
    
    const Self = @This();
    
    /// Initialize scanner
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }
    
    /// Scan directory starting from given path
    pub fn scanDirectory(self: *Self, path: []const u8) !*DirectoryEntry {
        var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => {
                std.log.err("Directory not found: {s}", .{path});
                return err;
            },
            error.AccessDenied => {
                std.log.err("Access denied to directory: {s}", .{path});
                return err;
            },
            else => return err,
        };
        defer dir.close();
        
        // Get directory metadata
        const dir_stat = try dir.stat();
        const dir_metadata = try FileMetadata.create(self.allocator, std.fs.path.basename(path), path, dir_stat);
        
        // Create root entry
        const root_entry = try DirectoryEntry.create(self.allocator, dir_metadata);
        
        // Scan directory contents
        try self.scanDirectoryRecursive(dir, root_entry, path, 0);
        
        return root_entry;
    }
    
    /// Recursively scan directory contents
    fn scanDirectoryRecursive(self: *Self, dir: std.fs.Dir, parent_entry: *DirectoryEntry, current_path: []const u8, depth: u32) !void {
        // Prevent infinite recursion
        const MAX_DEPTH = 10;
        if (depth > MAX_DEPTH) {
            std.log.warn("Maximum directory depth exceeded for path: {s}", .{current_path});
            return;
        }
        
        var iterator = dir.iterate();
        
        while (try iterator.next()) |entry| {
            // Skip hidden files and directories
            if (entry.name[0] == '.') continue;
            
            // Build full path
            var path_buffer: [1024]u8 = undefined;
            const full_path = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ current_path, entry.name });
            
            // Get file metadata
            const file_stat = blk: {
                if (entry.kind == .directory) {
                    var sub_dir = dir.openDir(entry.name, .{}) catch |err| {
                        std.log.warn("Failed to open subdirectory {s}: {}", .{ entry.name, err });
                        continue;
                    };
                    defer sub_dir.close();
                    break :blk try sub_dir.stat();
                } else {
                    var file = dir.openFile(entry.name, .{}) catch |err| {
                        std.log.warn("Failed to open file {s}: {}", .{ entry.name, err });
                        continue;
                    };
                    defer file.close();
                    break :blk try file.stat();
                }
            };
            
            // Create metadata for this entry
            const metadata = try FileMetadata.create(self.allocator, entry.name, full_path, file_stat);
            const dir_entry = try DirectoryEntry.create(self.allocator, metadata);
            
            // Add to parent
            try parent_entry.addChild(dir_entry);
            
            // Recursively scan subdirectories
            if (entry.kind == .directory) {
                var sub_dir = dir.openDir(entry.name, .{ .iterate = true }) catch |err| {
                    std.log.warn("Failed to iterate subdirectory {s}: {}", .{ entry.name, err });
                    continue;
                };
                defer sub_dir.close();
                
                try self.scanDirectoryRecursive(sub_dir, dir_entry, full_path, depth + 1);
            }
        }
        
        // Sort children for consistent display
        parent_entry.sortChildren();
    }
    
    /// Free all entries in a tree
    pub fn freeTree(self: *Self, root: *DirectoryEntry) void {
        root.deinit(self.allocator);
    }
};

/// Get file size as human-readable string
pub fn formatFileSize(size: u64, buffer: []u8) ![]const u8 {
    if (size < 1024) {
        return try std.fmt.bufPrint(buffer, "{d} B", .{size});
    } else if (size < 1024 * 1024) {
        return try std.fmt.bufPrint(buffer, "{d:.1} KB", .{@as(f64, @floatFromInt(size)) / 1024.0});
    } else if (size < 1024 * 1024 * 1024) {
        return try std.fmt.bufPrint(buffer, "{d:.1} MB", .{@as(f64, @floatFromInt(size)) / (1024.0 * 1024.0)});
    } else {
        return try std.fmt.bufPrint(buffer, "{d:.1} GB", .{@as(f64, @floatFromInt(size)) / (1024.0 * 1024.0 * 1024.0)});
    }
}