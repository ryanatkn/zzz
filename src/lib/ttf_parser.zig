const std = @import("std");

const log = std.log.scoped(.ttf_parser);

pub const GlyphID = u16;

pub const FontUnit = i16;

pub const Fixed = struct {
    value: i32,
    
    pub fn fromBytes(bytes: [4]u8) Fixed {
        return .{ .value = std.mem.readInt(i32, &bytes, .big) };
    }
    
    pub fn toFloat(self: Fixed) f32 {
        return @as(f32, @floatFromInt(self.value)) / 65536.0;
    }
};

pub const BoundingBox = struct {
    x_min: FontUnit,
    y_min: FontUnit,
    x_max: FontUnit,
    y_max: FontUnit,
};

pub const Point = struct {
    x: f32,
    y: f32,
    on_curve: bool,
};

pub const Glyph = struct {
    contours: [][]Point,
    bounds: BoundingBox,
    advance_width: u16,
    left_side_bearing: i16,
};

pub const TableRecord = struct {
    tag: [4]u8,
    checksum: u32,
    offset: u32,
    length: u32,
};

pub const OffsetTable = struct {
    version: Fixed,
    num_tables: u16,
    search_range: u16,
    entry_selector: u16,
    range_shift: u16,
};

pub const HeadTable = struct {
    version: Fixed,
    font_revision: Fixed,
    checksum_adjustment: u32,
    magic_number: u32,
    flags: u16,
    units_per_em: u16,
    created: i64,
    modified: i64,
    x_min: FontUnit,
    y_min: FontUnit,
    x_max: FontUnit,
    y_max: FontUnit,
    mac_style: u16,
    lowest_rec_ppem: u16,
    font_direction_hint: i16,
    index_to_loc_format: i16,
    glyph_data_format: i16,
};

pub const MaxpTable = struct {
    version: Fixed,
    num_glyphs: u16,
    max_points: u16,
    max_contours: u16,
    max_composite_points: u16,
    max_composite_contours: u16,
    max_zones: u16,
    max_twilight_points: u16,
    max_storage: u16,
    max_function_defs: u16,
    max_instruction_defs: u16,
    max_stack_elements: u16,
    max_size_of_instructions: u16,
    max_component_elements: u16,
    max_component_depth: u16,
};

pub const HheaTable = struct {
    version: Fixed,
    ascender: FontUnit,
    descender: FontUnit,
    line_gap: FontUnit,
    advance_width_max: u16,
    min_left_side_bearing: FontUnit,
    min_right_side_bearing: FontUnit,
    x_max_extent: FontUnit,
    caret_slope_rise: i16,
    caret_slope_run: i16,
    caret_offset: i16,
    reserved: [8]u8,
    metric_data_format: i16,
    number_of_h_metrics: u16,
};

pub const CmapTable = struct {
    version: u16,
    num_tables: u16,
};

pub const CmapEncodingRecord = struct {
    platform_id: u16,
    encoding_id: u16,
    offset: u32,
};

pub const TTFParser = struct {
    allocator: std.mem.Allocator,
    data: []const u8,
    tables: std.StringHashMap(TableRecord),
    head: ?HeadTable,
    maxp: ?MaxpTable,
    hhea: ?HheaTable,
    cmap_offset: ?u32,
    glyf_offset: ?u32,
    loca_offset: ?u32,
    hmtx_offset: ?u32,
    
    pub fn init(allocator: std.mem.Allocator, data: []const u8) !TTFParser {
        var parser = TTFParser{
            .allocator = allocator,
            .data = data,
            .tables = std.StringHashMap(TableRecord).init(allocator),
            .head = null,
            .maxp = null,
            .hhea = null,
            .cmap_offset = null,
            .glyf_offset = null,
            .loca_offset = null,
            .hmtx_offset = null,
        };
        
        try parser.parseOffsetTable();
        try parser.parseTables();
        
        return parser;
    }
    
    pub fn deinit(self: *TTFParser) void {
        var iter = self.tables.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.tables.deinit();
    }
    
    fn parseOffsetTable(self: *TTFParser) !void {
        if (self.data.len < 12) return error.InvalidFont;
        
        const version = std.mem.readInt(u32, self.data[0..4], .big);
        if (version != 0x00010000 and version != 0x4F54544F) {
            return error.UnsupportedFontFormat;
        }
        
        const num_tables = std.mem.readInt(u16, self.data[4..6], .big);
        
        var offset: usize = 12;
        var i: u16 = 0;
        while (i < num_tables) : (i += 1) {
            if (offset + 16 > self.data.len) return error.InvalidFont;
            
            var tag: [4]u8 = undefined;
            @memcpy(&tag, self.data[offset..offset + 4]);
            
            const record = TableRecord{
                .tag = tag,
                .checksum = std.mem.readInt(u32, self.data[offset + 4..][0..4], .big),
                .offset = std.mem.readInt(u32, self.data[offset + 8..][0..4], .big),
                .length = std.mem.readInt(u32, self.data[offset + 12..][0..4], .big),
            };
            
            const tag_str = try self.allocator.dupe(u8, record.tag[0..4]);
            try self.tables.put(tag_str, record);
            
            offset += 16;
        }
    }
    
    fn parseTables(self: *TTFParser) !void {
        // Parse and cache frequently used tables
        if (self.tables.get("head")) |head_record| {
            self.head = try self.parseHeadTable(head_record);
        } else {
            return error.MissingHeadTable;
        }
        
        if (self.tables.get("maxp")) |maxp_record| {
            self.maxp = try self.parseMaxpTable(maxp_record);
        } else {
            return error.MissingMaxpTable;
        }
        
        if (self.tables.get("hhea")) |hhea_record| {
            self.hhea = try self.parseHheaTable(hhea_record);
        } else {
            return error.MissingHheaTable;
        }
        
        if (self.tables.get("cmap")) |cmap_record| {
            self.cmap_offset = cmap_record.offset;
        } else {
            return error.MissingCmapTable;
        }
        
        if (self.tables.get("glyf")) |glyf_record| {
            self.glyf_offset = glyf_record.offset;
        }
        
        if (self.tables.get("loca")) |loca_record| {
            self.loca_offset = loca_record.offset;
        }
        
        if (self.tables.get("hmtx")) |hmtx_record| {
            self.hmtx_offset = hmtx_record.offset;
        }
    }
    
    fn parseHeadTable(self: *TTFParser, record: TableRecord) !HeadTable {
        const offset = record.offset;
        if (offset + 54 > self.data.len) return error.InvalidHeadTable;
        
        var version_bytes: [4]u8 = undefined;
        @memcpy(&version_bytes, self.data[offset..offset + 4]);
        var font_rev_bytes: [4]u8 = undefined;
        @memcpy(&font_rev_bytes, self.data[offset + 4..offset + 8]);
        
        return HeadTable{
            .version = Fixed.fromBytes(version_bytes),
            .font_revision = Fixed.fromBytes(font_rev_bytes),
            .checksum_adjustment = std.mem.readInt(u32, self.data[offset + 8..][0..4], .big),
            .magic_number = std.mem.readInt(u32, self.data[offset + 12..][0..4], .big),
            .flags = std.mem.readInt(u16, self.data[offset + 16..][0..2], .big),
            .units_per_em = std.mem.readInt(u16, self.data[offset + 18..][0..2], .big),
            .created = std.mem.readInt(i64, self.data[offset + 20..][0..8], .big),
            .modified = std.mem.readInt(i64, self.data[offset + 28..][0..8], .big),
            .x_min = std.mem.readInt(FontUnit, self.data[offset + 36..][0..2], .big),
            .y_min = std.mem.readInt(FontUnit, self.data[offset + 38..][0..2], .big),
            .x_max = std.mem.readInt(FontUnit, self.data[offset + 40..][0..2], .big),
            .y_max = std.mem.readInt(FontUnit, self.data[offset + 42..][0..2], .big),
            .mac_style = std.mem.readInt(u16, self.data[offset + 44..][0..2], .big),
            .lowest_rec_ppem = std.mem.readInt(u16, self.data[offset + 46..][0..2], .big),
            .font_direction_hint = std.mem.readInt(i16, self.data[offset + 48..][0..2], .big),
            .index_to_loc_format = std.mem.readInt(i16, self.data[offset + 50..][0..2], .big),
            .glyph_data_format = std.mem.readInt(i16, self.data[offset + 52..][0..2], .big),
        };
    }
    
    fn parseMaxpTable(self: *TTFParser, record: TableRecord) !MaxpTable {
        const offset = record.offset;
        if (offset + 6 > self.data.len) return error.InvalidMaxpTable;
        
        var version_bytes: [4]u8 = undefined;
        @memcpy(&version_bytes, self.data[offset..offset + 4]);
        const version = Fixed.fromBytes(version_bytes);
        const num_glyphs = std.mem.readInt(u16, self.data[offset + 4..][0..2], .big);
        
        if (version.value == 0x00005000) {
            return MaxpTable{
                .version = version,
                .num_glyphs = num_glyphs,
                .max_points = 0,
                .max_contours = 0,
                .max_composite_points = 0,
                .max_composite_contours = 0,
                .max_zones = 0,
                .max_twilight_points = 0,
                .max_storage = 0,
                .max_function_defs = 0,
                .max_instruction_defs = 0,
                .max_stack_elements = 0,
                .max_size_of_instructions = 0,
                .max_component_elements = 0,
                .max_component_depth = 0,
            };
        }
        
        if (offset + 32 > self.data.len) return error.InvalidMaxpTable;
        
        return MaxpTable{
            .version = version,
            .num_glyphs = num_glyphs,
            .max_points = std.mem.readInt(u16, self.data[offset + 6..][0..2], .big),
            .max_contours = std.mem.readInt(u16, self.data[offset + 8..][0..2], .big),
            .max_composite_points = std.mem.readInt(u16, self.data[offset + 10..][0..2], .big),
            .max_composite_contours = std.mem.readInt(u16, self.data[offset + 12..][0..2], .big),
            .max_zones = std.mem.readInt(u16, self.data[offset + 14..][0..2], .big),
            .max_twilight_points = std.mem.readInt(u16, self.data[offset + 16..][0..2], .big),
            .max_storage = std.mem.readInt(u16, self.data[offset + 18..][0..2], .big),
            .max_function_defs = std.mem.readInt(u16, self.data[offset + 20..][0..2], .big),
            .max_instruction_defs = std.mem.readInt(u16, self.data[offset + 22..][0..2], .big),
            .max_stack_elements = std.mem.readInt(u16, self.data[offset + 24..][0..2], .big),
            .max_size_of_instructions = std.mem.readInt(u16, self.data[offset + 26..][0..2], .big),
            .max_component_elements = std.mem.readInt(u16, self.data[offset + 28..][0..2], .big),
            .max_component_depth = std.mem.readInt(u16, self.data[offset + 30..][0..2], .big),
        };
    }
    
    fn parseHheaTable(self: *TTFParser, record: TableRecord) !HheaTable {
        const offset = record.offset;
        if (offset + 36 > self.data.len) return error.InvalidHheaTable;
        
        var version_bytes: [4]u8 = undefined;
        @memcpy(&version_bytes, self.data[offset..offset + 4]);
        
        return HheaTable{
            .version = Fixed.fromBytes(version_bytes),
            .ascender = std.mem.readInt(FontUnit, self.data[offset + 4..][0..2], .big),
            .descender = std.mem.readInt(FontUnit, self.data[offset + 6..][0..2], .big),
            .line_gap = std.mem.readInt(FontUnit, self.data[offset + 8..][0..2], .big),
            .advance_width_max = std.mem.readInt(u16, self.data[offset + 10..][0..2], .big),
            .min_left_side_bearing = std.mem.readInt(FontUnit, self.data[offset + 12..][0..2], .big),
            .min_right_side_bearing = std.mem.readInt(FontUnit, self.data[offset + 14..][0..2], .big),
            .x_max_extent = std.mem.readInt(FontUnit, self.data[offset + 16..][0..2], .big),
            .caret_slope_rise = std.mem.readInt(i16, self.data[offset + 18..][0..2], .big),
            .caret_slope_run = std.mem.readInt(i16, self.data[offset + 20..][0..2], .big),
            .caret_offset = std.mem.readInt(i16, self.data[offset + 22..][0..2], .big),
            .reserved = undefined,
            .metric_data_format = std.mem.readInt(i16, self.data[offset + 32..][0..2], .big),
            .number_of_h_metrics = std.mem.readInt(u16, self.data[offset + 34..][0..2], .big),
        };
    }
    
    pub fn getGlyphIndex(self: *TTFParser, codepoint: u32) !GlyphID {
        const cmap_offset = self.cmap_offset orelse return error.NoCmapTable;
        
        if (cmap_offset + 4 > self.data.len) return error.InvalidCmap;
        
        const version = std.mem.readInt(u16, self.data[cmap_offset..][0..2], .big);
        _ = version;
        const num_tables = std.mem.readInt(u16, self.data[cmap_offset + 2..][0..2], .big);
        
        var best_table: ?CmapEncodingRecord = null;
        var i: u16 = 0;
        while (i < num_tables) : (i += 1) {
            const record_offset = cmap_offset + 4 + (i * 8);
            if (record_offset + 8 > self.data.len) return error.InvalidCmap;
            
            const platform_id = std.mem.readInt(u16, self.data[record_offset..][0..2], .big);
            const encoding_id = std.mem.readInt(u16, self.data[record_offset + 2..][0..2], .big);
            const table_offset = std.mem.readInt(u32, self.data[record_offset + 4..][0..4], .big);
            
            if (platform_id == 0 and encoding_id == 3) {
                best_table = CmapEncodingRecord{
                    .platform_id = platform_id,
                    .encoding_id = encoding_id,
                    .offset = table_offset,
                };
                break;
            }
            
            if (platform_id == 3 and encoding_id == 1) {
                best_table = CmapEncodingRecord{
                    .platform_id = platform_id,
                    .encoding_id = encoding_id,
                    .offset = table_offset,
                };
            }
        }
        
        const table = best_table orelse return error.NoSuitableCmapTable;
        const subtable_offset = cmap_offset + table.offset;
        
        if (subtable_offset + 2 > self.data.len) return error.InvalidCmapSubtable;
        const format = std.mem.readInt(u16, self.data[subtable_offset..][0..2], .big);
        
        switch (format) {
            4 => return self.getGlyphIndexFormat4(subtable_offset, codepoint),
            else => return error.UnsupportedCmapFormat,
        }
    }
    
    fn getGlyphIndexFormat4(self: *TTFParser, offset: usize, codepoint: u32) !GlyphID {
        if (codepoint > 0xFFFF) return 0;
        const char_code = @as(u16, @intCast(codepoint));
        
        if (offset + 14 > self.data.len) return error.InvalidCmapFormat4;
        
        const seg_count_x2 = std.mem.readInt(u16, self.data[offset + 6..][0..2], .big);
        const seg_count = seg_count_x2 / 2;
        
        const end_codes_offset = offset + 14;
        const start_codes_offset = end_codes_offset + seg_count_x2 + 2;
        const id_deltas_offset = start_codes_offset + seg_count_x2;
        const id_range_offsets_offset = id_deltas_offset + seg_count_x2;
        
        var segment: u16 = 0;
        while (segment < seg_count) : (segment += 1) {
            const end_code_offset = end_codes_offset + (segment * 2);
            const start_code_offset = start_codes_offset + (segment * 2);
            
            if (end_code_offset + 2 > self.data.len or start_code_offset + 2 > self.data.len) {
                return error.InvalidCmapFormat4;
            }
            
            const end_code = std.mem.readInt(u16, self.data[end_code_offset..][0..2], .big);
            if (char_code > end_code) continue;
            
            const start_code = std.mem.readInt(u16, self.data[start_code_offset..][0..2], .big);
            if (char_code < start_code) return 0;
            
            const id_delta_offset = id_deltas_offset + (segment * 2);
            const id_range_offset_offset = id_range_offsets_offset + (segment * 2);
            
            if (id_delta_offset + 2 > self.data.len or id_range_offset_offset + 2 > self.data.len) {
                return error.InvalidCmapFormat4;
            }
            
            const id_range_offset = std.mem.readInt(u16, self.data[id_range_offset_offset..][0..2], .big);
            
            if (id_range_offset == 0) {
                const id_delta = std.mem.readInt(i16, self.data[id_delta_offset..][0..2], .big);
                return @intCast(@as(i32, char_code) + id_delta);
            } else {
                const glyph_index_offset = id_range_offset_offset + id_range_offset + ((char_code - start_code) * 2);
                if (glyph_index_offset + 2 > self.data.len) return error.InvalidCmapFormat4;
                
                const glyph_index = std.mem.readInt(u16, self.data[glyph_index_offset..][0..2], .big);
                if (glyph_index == 0) return 0;
                
                const id_delta = std.mem.readInt(i16, self.data[id_delta_offset..][0..2], .big);
                return @intCast(@as(i32, glyph_index) + id_delta);
            }
        }
        
        return 0;
    }
    
    pub fn getGlyphOffset(self: *TTFParser, glyph_id: GlyphID) !u32 {
        const loca_offset = self.loca_offset orelse return error.NoLocaTable;
        const head = self.head orelse return error.NoHeadTable;
        const maxp = self.maxp orelse return error.NoMaxpTable;
        
        if (glyph_id >= maxp.num_glyphs) return error.InvalidGlyphID;
        
        if (head.index_to_loc_format == 0) {
            const offset_pos = loca_offset + (@as(u32, glyph_id) * 2);
            if (offset_pos + 4 > self.data.len) return error.InvalidLocaTable;
            
            const offset1 = std.mem.readInt(u16, self.data[offset_pos..][0..2], .big);
            const offset2 = std.mem.readInt(u16, self.data[offset_pos + 2..][0..2], .big);
            
            if (offset1 == offset2) return error.EmptyGlyph;
            return @as(u32, offset1) * 2;
        } else {
            const offset_pos = loca_offset + (@as(u32, glyph_id) * 4);
            if (offset_pos + 8 > self.data.len) return error.InvalidLocaTable;
            
            const offset1 = std.mem.readInt(u32, self.data[offset_pos..][0..4], .big);
            const offset2 = std.mem.readInt(u32, self.data[offset_pos + 4..][0..4], .big);
            
            if (offset1 == offset2) return error.EmptyGlyph;
            return offset1;
        }
    }
    
    pub fn getGlyphMetrics(self: *TTFParser, glyph_id: GlyphID) !struct { advance_width: u16, left_side_bearing: i16 } {
        const hmtx_offset = self.hmtx_offset orelse return error.NoHmtxTable;
        const hhea = self.hhea orelse return error.NoHheaTable;
        const maxp = self.maxp orelse return error.NoMaxpTable;
        
        if (glyph_id >= maxp.num_glyphs) return error.InvalidGlyphID;
        
        if (glyph_id < hhea.number_of_h_metrics) {
            const metric_offset = hmtx_offset + (@as(u32, glyph_id) * 4);
            if (metric_offset + 4 > self.data.len) return error.InvalidHmtxTable;
            
            return .{
                .advance_width = std.mem.readInt(u16, self.data[metric_offset..][0..2], .big),
                .left_side_bearing = std.mem.readInt(i16, self.data[metric_offset + 2..][0..2], .big),
            };
        } else {
            const last_metric_offset = hmtx_offset + ((hhea.number_of_h_metrics - 1) * 4);
            if (last_metric_offset + 2 > self.data.len) return error.InvalidHmtxTable;
            
            const advance_width = std.mem.readInt(u16, self.data[last_metric_offset..][0..2], .big);
            
            const lsb_offset = hmtx_offset + (hhea.number_of_h_metrics * 4) + ((glyph_id - hhea.number_of_h_metrics) * 2);
            if (lsb_offset + 2 > self.data.len) return error.InvalidHmtxTable;
            
            return .{
                .advance_width = advance_width,
                .left_side_bearing = std.mem.readInt(i16, self.data[lsb_offset..][0..2], .big),
            };
        }
    }
};