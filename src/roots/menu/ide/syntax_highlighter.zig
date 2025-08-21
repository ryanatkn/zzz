/// Basic syntax highlighting for Zig files
/// Pattern-based highlighting without full AST parsing
const std = @import("std");
const colors = @import("../../../lib/core/colors.zig");
const constants = @import("constants.zig");
const Color = colors.Color;

/// Token type for syntax highlighting
pub const TokenType = enum {
    normal,
    keyword,
    type,
    string,
    comment,
    number,
    function,
    builtin,

    pub fn getColor(self: TokenType) Color {
        return switch (self) {
            .normal => Color{ .r = 200, .g = 200, .b = 200, .a = 255 },
            .keyword => Color{ .r = 150, .g = 120, .b = 255, .a = 255 }, // Purple-blue
            .type => Color{ .r = 80, .g = 200, .b = 180, .a = 255 }, // Cyan-green
            .string => Color{ .r = 255, .g = 200, .b = 100, .a = 255 }, // Yellow-orange
            .comment => Color{ .r = 120, .g = 120, .b = 120, .a = 255 }, // Gray
            .number => Color{ .r = 255, .g = 150, .b = 150, .a = 255 }, // Light red
            .function => Color{ .r = 100, .g = 255, .b = 150, .a = 255 }, // Light green
            .builtin => Color{ .r = 255, .g = 180, .b = 120, .a = 255 }, // Orange
        };
    }
};

/// Highlighted token with position and type
pub const HighlightedToken = struct {
    text: []const u8,
    token_type: TokenType,
    start_pos: u32,
    end_pos: u32,
};

/// Zig keywords for highlighting
const ZIG_KEYWORDS = [_][]const u8{
    "const",  "var",     "fn",       "struct",    "enum",     "union",  "if",        "else",     "switch",      "while",       "for",
    "return", "break",   "continue", "defer",     "errdefer", "try",    "catch",     "and",      "or",          "null",        "undefined",
    "true",   "false",   "pub",      "extern",    "export",   "inline", "noinline",  "comptime", "test",        "unreachable", "async",
    "await",  "suspend", "resume",   "nosuspend", "packed",   "align",  "allowzero", "volatile", "linksection", "threadlocal", "callconv",
    "opaque",
};

/// Zig built-in types
const ZIG_TYPES = [_][]const u8{
    "u8",    "u16",    "u32",        "u64",      "u128",   "usize",   "i8",          "i16",          "i32",      "i64",          "i128",           "isize",
    "f16",   "f32",    "f64",        "f128",     "bool",   "void",    "noreturn",    "type",         "anyerror", "comptime_int", "comptime_float", "c_short",
    "c_int", "c_long", "c_longlong", "c_ushort", "c_uint", "c_ulong", "c_ulonglong", "c_longdouble", "c_void",   "anytype",      "anyframe",       "anyopaque",
};

/// Zig built-in functions
const ZIG_BUILTINS = [_][]const u8{
    "@import",        "@cImport",          "@cInclude",      "@cDefine",         "@cUndef",          "@alignOf",          "@sizeOf",          "@offsetOf",
    "@bitSizeOf",     "@typeInfo",         "@typeName",      "@hasDecl",         "@hasField",        "@bitCast",          "@intCast",         "@floatCast",
    "@ptrCast",       "@alignCast",        "@enumToInt",     "@intToEnum",       "@errorToInt",      "@intToError",       "@truncate",        "@rem",
    "@mod",           "@divExact",         "@divFloor",      "@divTrunc",        "@sqrt",            "@sin",              "@cos",             "@tan",
    "@exp",           "@exp2",             "@log",           "@log2",            "@log10",           "@fabs",             "@floor",           "@ceil",
    "@trunc",         "@round",            "@mulAdd",        "@addWithOverflow", "@subWithOverflow", "@mulWithOverflow",  "@shlWithOverflow", "@This",
    "@returnAddress", "@errorReturnTrace", "@frame",         "@frameAddress",    "@frameSize",       "@setRuntimeSafety", "@setFloatMode",    "@panic",
    "@memcpy",        "@memset",           "@setAlignStack",
};

/// Simple syntax highlighter for Zig code
pub const ZigHighlighter = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    /// Highlight a line of Zig code with safety limits
    pub fn highlightLine(self: *Self, line: []const u8) ![]HighlightedToken {
        // Safety check: line length limit
        if (line.len > constants.SYNTAX.MAX_HIGHLIGHT_LINE_LENGTH) {
            // Return single token for oversized lines
            const tokens = try self.allocator.alloc(HighlightedToken, 1);
            tokens[0] = HighlightedToken{
                .text = line,
                .token_type = .normal,
                .start_pos = 0,
                .end_pos = @intCast(line.len),
            };
            return tokens;
        }

        var tokens = std.ArrayList(HighlightedToken).init(self.allocator);
        defer tokens.deinit();

        // Safety check: token count limit
        var token_count: u32 = 0;
        var i: u32 = 0;
        while (i < line.len and token_count < constants.SYNTAX.MAX_TOKENS_PER_LINE) {
            const start_pos = i;

            // Skip whitespace
            if (std.ascii.isWhitespace(line[i])) {
                i += 1;
                continue;
            }

            // Handle comments
            if (i + 1 < line.len and line[i] == '/' and line[i + 1] == '/') {
                try tokens.append(HighlightedToken{
                    .text = line[i..],
                    .token_type = .comment,
                    .start_pos = start_pos,
                    .end_pos = @intCast(line.len),
                });
                token_count += 1;
                break; // Rest of line is comment
            }

            // Handle strings
            if (line[i] == '"') {
                const end = self.findStringEnd(line, i);
                try tokens.append(HighlightedToken{
                    .text = line[i..end],
                    .token_type = .string,
                    .start_pos = start_pos,
                    .end_pos = end,
                });
                token_count += 1;
                i = end;
                continue;
            }

            // Handle character literals
            if (line[i] == '\'') {
                const end = self.findCharEnd(line, i);
                try tokens.append(HighlightedToken{
                    .text = line[i..end],
                    .token_type = .string,
                    .start_pos = start_pos,
                    .end_pos = end,
                });
                token_count += 1;
                i = end;
                continue;
            }

            // Handle numbers
            if (std.ascii.isDigit(line[i])) {
                const end = self.findNumberEnd(line, i);
                try tokens.append(HighlightedToken{
                    .text = line[i..end],
                    .token_type = .number,
                    .start_pos = start_pos,
                    .end_pos = end,
                });
                token_count += 1;
                i = end;
                continue;
            }

            // Handle identifiers (keywords, types, builtins, functions)
            if (std.ascii.isAlphabetic(line[i]) or line[i] == '_' or line[i] == '@') {
                const end = self.findIdentifierEnd(line, i);
                const identifier = line[i..end];

                const token_type = self.classifyIdentifier(identifier, line, i);
                try tokens.append(HighlightedToken{
                    .text = identifier,
                    .token_type = token_type,
                    .start_pos = start_pos,
                    .end_pos = end,
                });
                token_count += 1;
                i = end;
                continue;
            }

            // Default: single character
            i += 1;
        }

        // Convert to owned slice
        return try tokens.toOwnedSlice();
    }

    /// Find end of string literal
    fn findStringEnd(self: *Self, line: []const u8, start: u32) u32 {
        _ = self;
        var i = start + 1; // Skip opening quote
        while (i < line.len) {
            if (line[i] == '"' and (i == 0 or line[i - 1] != '\\')) {
                return i + 1; // Include closing quote
            }
            i += 1;
        }
        return @intCast(line.len); // Unterminated string
    }

    /// Find end of character literal
    fn findCharEnd(self: *Self, line: []const u8, start: u32) u32 {
        _ = self;
        var i = start + 1; // Skip opening quote
        while (i < line.len) {
            if (line[i] == '\'' and (i == 0 or line[i - 1] != '\\')) {
                return i + 1; // Include closing quote
            }
            i += 1;
        }
        return @intCast(line.len); // Unterminated char
    }

    /// Find end of number literal
    fn findNumberEnd(self: *Self, line: []const u8, start: u32) u32 {
        _ = self;
        var i = start;
        while (i < line.len and (std.ascii.isAlphabetic(line[i]) or std.ascii.isDigit(line[i]) or line[i] == '.' or line[i] == '_')) {
            i += 1;
        }
        return i;
    }

    /// Find end of identifier
    fn findIdentifierEnd(self: *Self, line: []const u8, start: u32) u32 {
        _ = self;
        var i = start;
        while (i < line.len and (std.ascii.isAlphabetic(line[i]) or std.ascii.isDigit(line[i]) or line[i] == '_')) {
            i += 1;
        }
        return i;
    }

    /// Classify an identifier as keyword, type, builtin, function, or normal
    fn classifyIdentifier(self: *Self, identifier: []const u8, line: []const u8, pos: u32) TokenType {
        _ = self;

        // Check for builtins (start with @)
        if (identifier.len > 0 and identifier[0] == '@') {
            for (ZIG_BUILTINS) |builtin| {
                if (std.mem.eql(u8, identifier, builtin)) {
                    return .builtin;
                }
            }
            return .builtin; // Any @identifier is likely a builtin
        }

        // Check for keywords
        for (ZIG_KEYWORDS) |keyword| {
            if (std.mem.eql(u8, identifier, keyword)) {
                return .keyword;
            }
        }

        // Check for types
        for (ZIG_TYPES) |type_name| {
            if (std.mem.eql(u8, identifier, type_name)) {
                return .type;
            }
        }

        // Check if it's likely a function (followed by '(')
        const end_pos = pos + @as(u32, @intCast(identifier.len));
        if (end_pos < line.len and line[end_pos] == '(') {
            return .function;
        }

        // Check if it's likely a type (starts with uppercase)
        if (identifier.len > 0 and std.ascii.isUpper(identifier[0])) {
            return .type;
        }

        return .normal;
    }

    /// Free tokens allocated by highlightLine
    pub fn freeTokens(self: *Self, tokens: []HighlightedToken) void {
        self.allocator.free(tokens);
    }
};

/// Check if a file should be syntax highlighted based on extension
pub fn shouldHighlight(filename: []const u8) bool {
    return std.mem.endsWith(u8, filename, ".zig");
}
