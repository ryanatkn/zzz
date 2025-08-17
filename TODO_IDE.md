# TODO: IDE Implementation

## Progress Summary

### ✅ Completed
- Created 6 UI component primitives in `src/lib/ui/`:
  - `panel.zig` - Panel layout system with resizable dividers
  - `scrollable.zig` - Scrollable container with scrollbars
  - `tree_view.zig` - Tree view for hierarchical data (file explorer)
  - `text_input.zig` - Single-line text input field
  - `text_area.zig` - Multi-line text editor with line numbers
  - `list_view.zig` - List view for terminal output
- Created IDE page at `src/menu/ide/+page.zig` with mockup layout
- Registered `/ide` route in router
- Added IDE button to main menu
- Fixed reactive imports to use `reactive/mod.zig`
- Build succeeds and IDE page is accessible

### Current State
- IDE page displays three-panel layout using text/links
- Shows file explorer structure, editor welcome text, terminal mockup
- All UI components ready but not yet integrated into IDE page
- Navigation working: Press ` to open menu, click IDE button

### 🔧 TODO: Full Integration
- Wire up actual component instances in IDE page
- Implement file I/O operations (list, read, write)
- Add text editing functionality (cursor, selection, typing)
- Terminal command execution (ls, cat, pwd)
- Syntax highlighting for Zig files
- Copy/paste support
- Search and replace
- File tree population from actual directory
- Resizable panels with drag dividers
- Save/load file functionality

### Architecture Notes
- Components use reactive signals for state management
- VTable pattern for polymorphic behavior
- Component base class provides common functionality
- Ready for self-editing when file I/O implemented

### Next Steps
1. Replace text mockup with actual component instances
2. Implement file system operations
3. Add keyboard input handling for text editing
4. Connect terminal to actual shell commands
5. Add syntax highlighting engine