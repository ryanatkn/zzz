const std = @import("std");
const ttf_parser = @import("ttf_parser.zig");
const testing = std.testing;

test "TTF Parser: Parse valid font header" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Minimal valid TTF header (12 bytes offset table + 1 table record)
    const test_data = [_]u8{
        // Offset table
        0x00, 0x01, 0x00, 0x00, // version (1.0)
        0x00, 0x01, // numTables = 1
        0x00, 0x10, // searchRange
        0x00, 0x00, // entrySelector
        0x00, 0x00, // rangeShift
        // Table record for 'head'
        'h', 'e', 'a', 'd', // tag
        0x00, 0x00, 0x00, 0x00, // checksum
        0x00, 0x00, 0x00, 0x1C, // offset = 28
        0x00, 0x00, 0x00, 0x36, // length = 54
        // Minimal head table at offset 28
        0x00, 0x01, 0x00, 0x00, // version
        0x00, 0x00, 0x00, 0x00, // fontRevision
        0x00, 0x00, 0x00, 0x00, // checksumAdjustment
        0x5F, 0x0F, 0x3C, 0xF5, // magicNumber
        0x00, 0x00, // flags
        0x04, 0x00, // unitsPerEm = 1024
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // created
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // modified
        0x00, 0x00, // xMin
        0x00, 0x00, // yMin
        0x04, 0x00, // xMax = 1024
        0x04, 0x00, // yMax = 1024
        0x00, 0x00, // macStyle
        0x00, 0x08, // lowestRecPPEM
        0x00, 0x02, // fontDirectionHint
        0x00, 0x00, // indexToLocFormat
        0x00, 0x00, // glyphDataFormat
    };
    
    // This should fail with MissingMaxpTable since we only have head
    const result = ttf_parser.TTFParser.init(allocator, &test_data);
    try testing.expectError(error.MissingMaxpTable, result);
}

test "TTF Parser: Handle invalid font format" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Invalid version number
    const test_data = [_]u8{
        0xFF, 0xFF, 0xFF, 0xFF, // Invalid version
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    };
    
    const result = ttf_parser.TTFParser.init(allocator, &test_data);
    try testing.expectError(error.UnsupportedFontFormat, result);
}

test "TTF Parser: Handle empty data" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const test_data = [_]u8{};
    
    const result = ttf_parser.TTFParser.init(allocator, &test_data);
    try testing.expectError(error.InvalidFont, result);
}

test "TTF Parser: Table storage and retrieval" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var parser = ttf_parser.TTFParser{
        .allocator = allocator,
        .data = &[_]u8{},
        .tables = std.StringHashMap(ttf_parser.TableRecord).init(allocator),
        .head = null,
        .maxp = null,
        .hhea = null,
        .cmap_offset = null,
        .glyf_offset = null,
        .loca_offset = null,
        .hmtx_offset = null,
    };
    defer parser.deinit();
    
    // Test adding and retrieving table records
    const test_record = ttf_parser.TableRecord{
        .tag = [_]u8{'t', 'e', 's', 't'},
        .checksum = 0x12345678,
        .offset = 100,
        .length = 200,
    };
    
    const key = try allocator.dupe(u8, "test");
    defer allocator.free(key);
    
    try parser.tables.put(key, test_record);
    
    const retrieved = parser.tables.get("test");
    try testing.expect(retrieved != null);
    try testing.expectEqual(@as(u32, 100), retrieved.?.offset);
    try testing.expectEqual(@as(u32, 200), retrieved.?.length);
}

test "TTF Parser: Glyph index lookup - ASCII" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create a minimal parser with cmap data
    var parser = ttf_parser.TTFParser{
        .allocator = allocator,
        .data = undefined, // Will be set to mock data
        .tables = std.StringHashMap(ttf_parser.TableRecord).init(allocator),
        .head = null,
        .maxp = null,
        .hhea = null,
        .cmap_offset = 0,
        .glyf_offset = null,
        .loca_offset = null,
        .hmtx_offset = null,
    };
    defer parser.deinit();
    
    // Minimal cmap format 4 table for ASCII 'A' (65) -> glyph 1
    const cmap_data = [_]u8{
        // cmap header
        0x00, 0x00, // version
        0x00, 0x01, // numTables = 1
        // encoding record
        0x00, 0x03, // platformID = 3 (Windows)
        0x00, 0x01, // encodingID = 1 (Unicode BMP)
        0x00, 0x00, 0x00, 0x0C, // offset to subtable = 12
        // Format 4 subtable at offset 12
        0x00, 0x04, // format = 4
        0x00, 0x20, // length = 32
        0x00, 0x00, // language
        0x00, 0x04, // segCountX2 = 4 (2 segments)
        0x00, 0x04, // searchRange
        0x00, 0x01, // entrySelector
        0x00, 0x00, // rangeShift
        // endCode array
        0x00, 0x41, // endCode[0] = 65 ('A')
        0xFF, 0xFF, // endCode[1] = 0xFFFF (end marker)
        0x00, 0x00, // reserved padding
        // startCode array  
        0x00, 0x41, // startCode[0] = 65 ('A')
        0xFF, 0xFF, // startCode[1] = 0xFFFF
        // idDelta array
        0xFF, 0xC0, // idDelta[0] = -64 (65 - 64 = glyph 1)
        0x00, 0x01, // idDelta[1] = 1
        // idRangeOffset array
        0x00, 0x00, // idRangeOffset[0] = 0
        0x00, 0x00, // idRangeOffset[1] = 0
    };
    
    parser.data = &cmap_data;
    
    // Test ASCII 'A' maps to glyph 1
    const glyph_id = try parser.getGlyphIndex(65);
    try testing.expectEqual(@as(ttf_parser.GlyphID, 1), glyph_id);
    
    // Test unmapped character returns 0
    const unmapped = try parser.getGlyphIndex(32);
    try testing.expectEqual(@as(ttf_parser.GlyphID, 0), unmapped);
}

test "TTF Parser: Fixed type conversions" {
    // Test Fixed type
    const bytes = [_]u8{ 0x00, 0x01, 0x80, 0x00 };
    const fixed = ttf_parser.Fixed.fromBytes(bytes);
    try testing.expectEqual(@as(i32, 0x00018000), fixed.value);
    
    const float_val = fixed.toFloat();
    try testing.expectApproxEqAbs(@as(f32, 1.5), float_val, 0.001);
}

test "TTF Parser: Memory cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create and destroy parser multiple times to check for leaks
    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        var parser = ttf_parser.TTFParser{
            .allocator = allocator,
            .data = &[_]u8{},
            .tables = std.StringHashMap(ttf_parser.TableRecord).init(allocator),
            .head = null,
            .maxp = null,
            .hhea = null,
            .cmap_offset = null,
            .glyf_offset = null,
            .loca_offset = null,
            .hmtx_offset = null,
        };
        
        // Add some table entries
        const key1 = try allocator.dupe(u8, "test1");
        const key2 = try allocator.dupe(u8, "test2");
        
        try parser.tables.put(key1, ttf_parser.TableRecord{
            .tag = [_]u8{'t', 'e', 's', '1'},
            .checksum = 0,
            .offset = 0,
            .length = 0,
        });
        try parser.tables.put(key2, ttf_parser.TableRecord{
            .tag = [_]u8{'t', 'e', 's', '2'},
            .checksum = 0,
            .offset = 0,
            .length = 0,
        });
        
        parser.deinit();
    }
    
    // If we get here without memory leaks, the test passes
    try testing.expect(true);
}

test "TTF Parser: Bounds checking" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Data that's too small for proper parsing
    const test_data = [_]u8{
        0x00, 0x01, 0x00, 0x00, // version
        0x00, 0x05, // numTables = 5 (but we don't have space for 5 tables)
    };
    
    const result = ttf_parser.TTFParser.init(allocator, &test_data);
    try testing.expectError(error.InvalidFont, result);
}