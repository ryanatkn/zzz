const std = @import("std");

/// Multi-faceted faction tags that determine how entities relate to each other
/// Entities can have multiple tags creating emergent relationship behaviors
pub const FactionTag = enum {
    // Being type tags (what kind of being you are)
    halfling,
    gnome,
    elf,
    dwarf,
    goblin,
    fey,
    beast,
    elemental,
    golem,

    // Being state tags (living/non-living nature)
    living, // Normal living being
    undead, // Reanimated being, hostile to living
    construct, // Never-alive being (golems, elementals)

    // Allegiance tags (who you serve)
    kingdom_guard,
    bandit,
    merchant_guild,
    forest_warden,
    necromancer_cult,

    // Behavioral tags (how you act)
    territorial,
    pack_hunter,
    solitary,
    trader,
    guardian,

    // Modifier tags (magical effects)
    corrupted, // Twisted by dark magic
    blessed, // Protected by divine magic

    // State tags (temporary, can change)
    charmed,
    enraged,
    fleeing,
    defending_home,
};

pub const FactionSet = std.EnumSet(FactionTag);

/// Entity faction data with multiple tags for emergent behavior
pub const EntityFactions = struct {
    tags: FactionSet,

    pub fn init() EntityFactions {
        return .{ .tags = FactionSet.initEmpty() };
    }

    pub fn initWithTags(tag_list: []const FactionTag) EntityFactions {
        var factions = init();
        for (tag_list) |tag| {
            factions.tags.insert(tag);
        }
        return factions;
    }

    pub fn hasTag(self: EntityFactions, tag: FactionTag) bool {
        return self.tags.contains(tag);
    }

    pub fn addTag(self: *EntityFactions, tag: FactionTag) void {
        self.tags.insert(tag);
    }

    pub fn removeTag(self: *EntityFactions, tag: FactionTag) void {
        self.tags.remove(tag);
    }

    pub fn getSharedTagCount(self: EntityFactions, other: EntityFactions) u32 {
        return @intCast(self.tags.intersectWith(other.tags).count());
    }
};

/// Relationship between two entities based on their faction tags
pub const FactionRelation = enum {
    friendly, // Won't attack, may interact positively
    neutral, // Ignores unless provoked
    suspicious, // May attack if approached too closely
    hostile, // Attacks on sight
};

/// Calculate relationship from entity A's perspective toward entity B
pub fn calculateRelation(from: EntityFactions, to: EntityFactions) FactionRelation {
    // Priority-based rules (highest priority wins)

    // 1. Charmed entities are friendly to their charmer's faction
    if (from.hasTag(.charmed) and sharesCharmerFaction(from, to)) {
        return .friendly;
    }

    // 2. Undead are hostile to all living things (unless same cult)
    if (from.hasTag(.undead) and to.hasTag(.living)) {
        if (!sharesCult(from, to)) return .hostile;
    }
    if (to.hasTag(.undead) and from.hasTag(.living)) {
        if (!sharesCult(from, to)) return .hostile;
    }

    // 3. Pack hunters are friendly with their pack
    if (from.hasTag(.pack_hunter) and to.hasTag(.pack_hunter)) {
        if (sharesRace(from, to)) return .friendly;
    }

    // 4. Guards vs bandits are always hostile
    if (from.hasTag(.kingdom_guard) and to.hasTag(.bandit)) {
        return .hostile;
    }
    if (from.hasTag(.bandit) and to.hasTag(.kingdom_guard)) {
        return .hostile;
    }

    // 5. Merchants are friendly to most (unless bandit)
    if (from.hasTag(.merchant_guild)) {
        if (to.hasTag(.bandit)) return .suspicious;
        return .friendly;
    }

    // 6. Territorial creatures are suspicious of others in their territory
    if (from.hasTag(.territorial) and !sharesAllegiance(from, to)) {
        return .suspicious;
    }

    // 7. Corrupted vs blessed are hostile
    if (from.hasTag(.corrupted) and to.hasTag(.blessed)) {
        return .hostile;
    }
    if (from.hasTag(.blessed) and to.hasTag(.corrupted)) {
        return .hostile;
    }

    // Default based on shared tags
    const shared_count = from.getSharedTagCount(to);
    if (shared_count >= 2) return .friendly;
    if (shared_count == 1) return .neutral;
    return .suspicious;
}

// Helper functions for faction relationship calculations

fn sharesCharmerFaction(charmed: EntityFactions, other: EntityFactions) bool {
    // For now, simple implementation - charmed creatures are friendly to kingdom_guard
    // TODO: Track actual charmer faction when charm spells are implemented
    return charmed.hasTag(.charmed) and other.hasTag(.kingdom_guard);
}

fn sharesCult(a: EntityFactions, b: EntityFactions) bool {
    return (a.hasTag(.necromancer_cult) and b.hasTag(.necromancer_cult));
}

fn sharesRace(a: EntityFactions, b: EntityFactions) bool {
    // Check if they share any being type tag
    const being_types = [_]FactionTag{ .halfling, .gnome, .elf, .dwarf, .goblin, .fey, .beast, .elemental, .golem };

    for (being_types) |race| {
        if (a.hasTag(race) and b.hasTag(race)) {
            return true;
        }
    }
    return false;
}

fn sharesAllegiance(a: EntityFactions, b: EntityFactions) bool {
    // Check if they share any allegiance tag
    const allegiances = [_]FactionTag{ .kingdom_guard, .bandit, .merchant_guild, .forest_warden, .necromancer_cult };

    for (allegiances) |allegiance| {
        if (a.hasTag(allegiance) and b.hasTag(allegiance)) {
            return true;
        }
    }
    return false;
}

// Test functions to verify faction logic
test "basic faction creation" {
    const std_test = std.testing;

    const player = EntityFactions.initWithTags(&.{ .halfling, .kingdom_guard, .living });
    const guard = EntityFactions.initWithTags(&.{ .halfling, .kingdom_guard, .living });
    const bandit = EntityFactions.initWithTags(&.{ .goblin, .bandit, .living });

    try std_test.expect(calculateRelation(player, guard) == .friendly);
    try std_test.expect(calculateRelation(player, bandit) == .hostile);
    try std_test.expect(calculateRelation(guard, bandit) == .hostile);
}

test "undead hostility" {
    const std_test = std.testing;

    const living = EntityFactions.initWithTags(&.{ .halfling, .living });
    const undead = EntityFactions.initWithTags(&.{ .halfling, .undead });

    try std_test.expect(calculateRelation(living, undead) == .hostile);
    try std_test.expect(calculateRelation(undead, living) == .hostile);
}

test "pack behavior" {
    const std_test = std.testing;

    const wolf1 = EntityFactions.initWithTags(&.{ .beast, .pack_hunter, .living });
    const wolf2 = EntityFactions.initWithTags(&.{ .beast, .pack_hunter, .living });
    const lone_bear = EntityFactions.initWithTags(&.{ .beast, .solitary, .living });

    try std_test.expect(calculateRelation(wolf1, wolf2) == .friendly);
    // Both are beasts and living (2 shared tags) = friendly relationship
    try std_test.expect(calculateRelation(wolf1, lone_bear) == .friendly);
}
