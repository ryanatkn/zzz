# TODO: Cleanup Round 2 - Post Particle/Status Refactor

**Status**: New  
**Date**: December 2024  
**Context**: Follow-up cleanup after particle/status/effect naming refactor

## 🎯 High Priority - Naming Consistency

### 1. **Particle System Variable Names**
- [ ] `src/lib/rendering/gpu.zig:468` - Rename `effect_create_info` → `particle_create_info`
- [ ] Update related pipeline creation variable names for consistency
- [ ] Search for any remaining "effect" references that should be "particle"

### 2. **Dead Code Patterns**
- [ ] `src/hex/controls.zig:17,141-142` - Review dead_player_handler usage
  - Consider simplifying the DeadPlayerHandler pattern
  - May be over-engineered for simple respawn logic
- [ ] Check if "Legacy HUD" comment at line 53 is still accurate

## 🔧 Medium Priority - Code Quality

### 3. **Incomplete Implementations**
- [ ] `src/hex/spells.zig:536` - TODO for multishot spell bullet spawning
  - Implement proper multi-bullet spawning with game.addBullet()
  - Remove TODO comment once complete

### 4. **Unused Imports & Dependencies**
- [ ] Review imports after particle refactor
- [ ] Check for unused game_input imports
- [ ] Verify all debug logger instances are used

### 5. **Color Constants Organization**
- [ ] `src/hex/hex_game.zig:657,725` - COLOR_DEAD usage
  - Consider if this belongs with other status colors
  - Verify consistency with new status system

## 📝 Low Priority - Documentation

### 6. **Comment Updates**
- [ ] Update any remaining "effect" comments to use "particle" terminology
- [ ] Review and update misleading "temporary" or "hack" comments
- [ ] Add clarity to complex particle/status interactions

### 7. **Architecture Documentation**
- [ ] Document the new particle/status/effect separation clearly
- [ ] Update any diagrams or high-level docs referencing old patterns

## 🏗️ Architectural Considerations

### 8. **Potential Simplifications**
- [ ] Dead player input handling could be simplified
- [ ] Consider if particle instances batching can be improved
- [ ] Review if status system needs all current complexity

### 9. **Performance Opportunities**
- [ ] Profile particle system after refactor
- [ ] Check if status updates can be batched
- [ ] Verify no performance regression from renaming

## ✅ Already Completed (from refactor)
- Renamed effects → particles for visual system
- Renamed effects → statuses for gameplay modifiers  
- Updated all imports and references
- Fixed shader compilation and loading
- Verified game runs successfully

## 📊 Metrics to Track
- Lines of code removed: TBD
- Performance impact: TBD
- Build time change: TBD

## 🚀 Next Session Focus
1. Start with high priority naming consistency fixes
2. Address the multishot TODO
3. Simplify dead player handler if possible
4. Update documentation as we go

---

**Estimated effort**: 1-2 hours  
**Risk level**: Low (mostly naming and cleanup)  
**Testing required**: Compile and basic gameplay after each change