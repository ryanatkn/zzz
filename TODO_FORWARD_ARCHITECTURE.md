# TODO: Forward Architecture Evolution

## Status: Active Planning

This document tracks the architectural evolution of Dealt from a game engine to a comprehensive graphics and media programming environment.

## Current State (Good)

The existing capability-based organization in `src/lib/` is working well:
- **Core primitives** (`core/`) - types, math, colors, memory management
- **Platform layer** (`platform/`) - SDL3, input, window management  
- **Rendering system** (`rendering/`) - GPU, shaders, camera, drawing
- **Physics system** (`physics/`) - collision, shapes
- **Reactive UI** (`reactive/`) - Svelte 5 implementation
- **Font & text** (`font/`, `text/`) - TTF parsing, SDF rendering
- **Vector graphics** (`vector/`) - GPU-accelerated curves
- **UI components** (`ui/`) - reactive components with lifecycle

## Architectural Principles

### Core Philosophy
- **Capability-based, not layer-based** - organize by what modules enable
- **No texture assets** - pure algorithmic/procedural generation
- **GPU-first** - leverage modern graphics hardware
- **Reactive by design** - instant response to state changes

### Design Rules
1. Modules can use any other module's capabilities (no artificial layers)
2. Interfaces emerge from actual needs, not speculation
3. Avoid premature abstraction
4. Maintain clean capability boundaries

## Evolution Milestones

### Phase 1: Capability Interfaces (When Needed)
**Trigger**: When 3+ components need same interface
**Timeline**: As patterns emerge

- [ ] Create `lib/capabilities/` directory
- [ ] Add `drawable.zig` when 3+ drawable types exist
- [ ] Add `updatable.zig` when multiple update loops needed
- [ ] Add `serializable.zig` when persistence patterns emerge
- [ ] Document capability contracts clearly

### Phase 2: Creative Tools Foundation
**Trigger**: First creative tool beyond Hex
**Timeline**: Next major project

- [ ] Create `src/tools/` directory structure
- [ ] Extract shared tool infrastructure
- [ ] Build first creative tool (candidates below)
- [ ] Establish tool-to-library patterns

**Candidate Tools** (from LIBRARY_ARCHITECTURE.md):
- **Shader Playground** - live HLSL editing with instant feedback
- **Font Forge** - typography design and manipulation
- **Vector Studio** - Bezier curve editor
- **Particle Designer** - visual effects creation
- **Color Lab** - color theory and palette generation

### Phase 3: Media Expansion
**Trigger**: Need for audio or other media types
**Timeline**: When use case emerges

- [ ] Reorganize `rendering/` → `media/graphics/`
- [ ] Add `media/audio/` for sound synthesis
- [ ] Add `media/effects/` for cross-media effects
- [ ] Maintain procedural generation philosophy

### Phase 4: Framework Extraction
**Trigger**: 3rd application using common patterns
**Timeline**: After 2-3 tools built

- [ ] Extract application framework to `lib/frameworks/app/`
- [ ] Create game framework in `lib/frameworks/game/`
- [ ] Build creative framework in `lib/frameworks/creative/`
- [ ] Document framework patterns

### Phase 5: Plugin Architecture
**Trigger**: Need for user extensions
**Timeline**: When ecosystem develops

- [ ] Design capability-based plugin interface
- [ ] Implement plugin loading and sandboxing
- [ ] Create plugin API documentation
- [ ] Build example plugins

## Near-term Tasks (Next 3 Months)

### Documentation
- [ ] Document each module's capabilities in README files
- [ ] Create architecture decision records (ADRs)
- [ ] Build capability dependency graph

### Code Organization
- [ ] Audit current imports for capability focus
- [ ] Identify emerging patterns for extraction
- [ ] Remove any circular dependencies

### Performance
- [ ] Profile current architecture bottlenecks
- [ ] Optimize hot paths
- [ ] Document performance characteristics

## Evaluation Criteria

**When to advance phases:**
- Real need exists (not speculative)
- Pattern appears 3+ times
- Current structure becomes limiting
- Performance or maintainability degrades

**When to reconsider architecture:**
- Reaching ~100 files in lib/
- Adding 3rd major application
- Supporting plugin systems
- Building shareable components

## Anti-patterns to Avoid

1. **Premature Abstraction** - don't create interfaces before need
2. **Layer Cake** - avoid artificial layer restrictions
3. **Framework-itis** - don't over-framework simple problems
4. **Asset Creep** - maintain no-asset philosophy
5. **Big Bang Refactor** - evolve incrementally

## Success Metrics

- **Clean imports** - each file imports only needed capabilities
- **No circular deps** - clear capability flow
- **Fast compilation** - incremental builds under 3 seconds
- **Easy navigation** - developers find code quickly
- **Natural growth** - new features fit without restructuring

## Long-term Vision (1-2 Years)

Dealt becomes a platform for:
- **Creative coding** - algorithmic art and visualization
- **Game development** - unique visual styles
- **Tool creation** - custom creative tools
- **Educational content** - interactive learning
- **Eventually** - components of a desktop environment

All while maintaining:
- Pure procedural generation
- GPU-first performance
- Mathematical beauty
- Clean architecture

## References

- [LIBRARY_ARCHITECTURE.md](./LIBRARY_ARCHITECTURE.md) - detailed architectural alternatives
- [src/lib/README.md](./src/lib/README.md) - current library documentation
- [CLAUDE.md](./CLAUDE.md) - development guidelines

---

*Last Updated: 2025-01-14*
*Status: Active planning and incremental evolution*