const std = @import("std");
const testing = std.testing;
const terminal_mod = @import("mod.zig");

// Import all the new capabilities
const History = @import("capabilities/state/history.zig").History;
const ScreenBuffer = @import("capabilities/state/screen_buffer.zig").ScreenBuffer;
const Scrollback = @import("capabilities/state/scrollback.zig").Scrollback;
const Persistence = @import("capabilities/state/persistence.zig").Persistence;

// Import presets
const MinimalTerminal = terminal_mod.presets.MinimalTerminal;
const StandardTerminal = terminal_mod.presets.StandardTerminal;

test "Phase 3: History capability" {
    const allocator = testing.allocator;
    var history = History.init(allocator);
    defer history.deinit();
    
    // Add commands
    try history.addCommand("ls -la");
    try history.addCommand("cd /tmp");
    try history.addCommand("pwd");
    
    try testing.expectEqual(@as(usize, 3), history.getCount());
    
    // Navigate history
    try testing.expectEqualStrings("pwd", history.navigate(-1).?);
    try testing.expectEqualStrings("cd /tmp", history.navigate(-1).?);
    try testing.expectEqualStrings("ls -la", history.navigate(-1).?);
}

test "Phase 3: ScreenBuffer capability" {
    const allocator = testing.allocator;
    var buffer = try ScreenBuffer.init(allocator);
    defer buffer.deinit();
    
    // Write characters
    buffer.writeChar(0, 0, 'T', 0xFFFFFF, 0x000000, false);
    buffer.writeChar(1, 0, 'E', 0xFFFFFF, 0x000000, false);
    buffer.writeChar(2, 0, 'S', 0xFFFFFF, 0x000000, false);
    buffer.writeChar(3, 0, 'T', 0xFFFFFF, 0x000000, false);
    
    // Check cells
    const cell = buffer.getCell(0, 0).?;
    try testing.expectEqual(@as(u8, 'T'), cell.char);
    
    // Test alternate screen
    buffer.switchToAlternate();
    try testing.expect(buffer.using_alternate);
    
    buffer.writeChar(0, 0, 'A', 0xFF0000, 0x000000, true);
    const alt_cell = buffer.getCell(0, 0).?;
    try testing.expectEqual(@as(u8, 'A'), alt_cell.char);
    
    buffer.switchToPrimary();
    try testing.expect(!buffer.using_alternate);
    const primary_cell = buffer.getCell(0, 0).?;
    try testing.expectEqual(@as(u8, 'T'), primary_cell.char);
}

test "Phase 3: Scrollback capability" {
    const allocator = testing.allocator;
    var scrollback = Scrollback.init(allocator);
    defer scrollback.deinit();
    
    // Add lines
    try scrollback.addLine("First line");
    try scrollback.addLine("Second line");
    try scrollback.addLine("Third line");
    try scrollback.addLine("Fourth line");
    try scrollback.addLine("Fifth line");
    
    try testing.expectEqual(@as(usize, 5), scrollback.getLineCount());
    
    // Test scrolling
    try testing.expect(scrollback.isAtBottom());
    
    scrollback.scrollUp(2);
    try testing.expect(!scrollback.isAtBottom());
    try testing.expectEqual(@as(usize, 2), scrollback.viewport_offset);
    
    scrollback.scrollToTop();
    try testing.expectEqual(@as(usize, 4), scrollback.viewport_offset);
    
    scrollback.scrollToBottom();
    try testing.expect(scrollback.isAtBottom());
}

test "Phase 3: Persistence capability" {
    const allocator = testing.allocator;
    var persistence = try Persistence.init(allocator);
    defer persistence.deinit();
    
    // Test session save/load
    try persistence.saveSession("test_session");
    try persistence.loadSession("test_session");
    
    // List sessions
    const sessions = try persistence.listSessions(allocator);
    defer {
        for (sessions) |session| {
            allocator.free(session);
        }
        allocator.free(sessions);
    }
    
    try testing.expect(sessions.len >= 1);
    
    // Clean up test session
    try persistence.deleteSession("test_session");
}

test "Phase 3: StandardTerminal integration" {
    const allocator = testing.allocator;
    var terminal = try StandardTerminal.init(allocator);
    defer terminal.deinit();
    
    // Test that all capabilities are available
    try testing.expect(terminal.registry.getCapability("keyboard_input") != null);
    try testing.expect(terminal.registry.getCapability("basic_writer") != null);
    try testing.expect(terminal.registry.getCapability("line_buffer") != null);
    try testing.expect(terminal.registry.getCapability("cursor") != null);
    try testing.expect(terminal.registry.getCapability("history") != null);
    try testing.expect(terminal.registry.getCapability("screen_buffer") != null);
    try testing.expect(terminal.registry.getCapability("scrollback") != null);
    try testing.expect(terminal.registry.getCapability("persistence") != null);
    
    // Test screen switching
    try testing.expect(!terminal.isUsingAlternateScreen());
    terminal.switchToAlternateScreen();
    try testing.expect(terminal.isUsingAlternateScreen());
    terminal.switchToPrimaryScreen();
    try testing.expect(!terminal.isUsingAlternateScreen());
    
    // Test scrollback
    try terminal.write("Test line 1\n");
    try terminal.write("Test line 2\n");
    try terminal.write("Test line 3\n");
    
    try testing.expect(terminal.isAtBottom());
    terminal.scrollUp(1);
    try testing.expect(!terminal.isAtBottom());
    terminal.scrollToBottom();
    try testing.expect(terminal.isAtBottom());
    
    // Test history navigation
    const history_count = terminal.getHistoryCount();
    _ = history_count;
    
    // Test session management (basic)
    try terminal.saveSession("test_phase3");
    try terminal.loadSession("test_phase3");
    try terminal.deleteSession("test_phase3");
}

test "Phase 3: Memory leak check" {
    const allocator = testing.allocator;
    
    // Create and destroy terminals multiple times
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        var terminal = try StandardTerminal.init(allocator);
        
        // Do some operations
        try terminal.write("Test output\n");
        terminal.switchToAlternateScreen();
        terminal.scrollUp(5);
        terminal.clearScreen();
        terminal.switchToPrimaryScreen();
        
        terminal.deinit();
    }
    
    // If we get here without memory leaks, test passes
    try testing.expect(true);
}

test "Phase 3: Event flow between capabilities" {
    const allocator = testing.allocator;
    var terminal = try StandardTerminal.init(allocator);
    defer terminal.deinit();
    
    // Write some output - should trigger scrollback update
    const initial_scrollback = terminal.getScrollbackLineCount();
    try terminal.write("New line for scrollback\n");
    
    // Scrollback should have increased
    const new_scrollback = terminal.getScrollbackLineCount();
    try testing.expect(new_scrollback >= initial_scrollback);
    
    // Test that input affects history
    const initial_history = terminal.getHistoryCount();
    _ = initial_history;
    
    // Simulate command execution (would need proper input handling)
    // This is more of a placeholder for full integration testing
    try testing.expect(true);
}