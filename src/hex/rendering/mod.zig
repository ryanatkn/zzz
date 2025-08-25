// Hex rendering subsystems - extracted from game_renderer.zig
// Each module focuses on a specific rendering concern and reuses lib/rendering utilities

pub const EntityBatchRenderer = @import("entity_batch.zig").EntityBatchRenderer;
pub const EffectsRenderer = @import("effects.zig").EffectsRenderer;
pub const UIOverlayRenderer = @import("ui_overlay.zig").UIOverlayRenderer;
pub const AbilityBarRenderer = @import("ability_bar.zig").AbilityBarRenderer;

// Re-export for convenience
pub const entity_batch = @import("entity_batch.zig");
pub const effects = @import("effects.zig");
pub const ui_overlay = @import("ui_overlay.zig");
pub const ability_bar = @import("ability_bar.zig");
