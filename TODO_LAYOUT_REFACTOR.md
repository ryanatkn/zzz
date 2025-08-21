TODO: Layout Module Refactoring

  Goal

  Refactor the layout module into smaller, more focused abstractions with clear single
  responsibilities.

  Current State

  - src/lib/layout/mod.zig - Monolithic re-export file mixing multiple concerns
  - src/lib/layout/primitives/ - Well-structured but flexbox doesn't belong here
  - src/lib/layout/gpu/ - GPU-specific implementation mixed with hybrid logic
  - src/lib/layout/box_model.zig - Good but should be in engines
  - src/lib/layout/text_baseline.zig - Text-specific, needs better home
  - src/roots/menu/layout_benchmark/ - Contains reusable layout abstractions

  Proposed Structure

  Phase 1: Core Type Extraction

  - Create src/lib/layout/types.zig
    - Extract common enums (LayoutMode, Direction, Alignment, etc.)
    - Define shared structs (LayoutResult, LayoutContext)
    - Move from various files into single source of truth

  Phase 2: Layout Engines

  - Create src/lib/layout/engines/ directory
  - Move box_model.zig → engines/box_model.zig
  - Move primitives/flexbox.zig → engines/flexbox.zig
  - Create engines/absolute.zig for absolute positioning
  - Create engines/mod.zig with clean re-exports

  Phase 3: Measurement System

  - Create src/lib/layout/measurement/ directory
  - Extract constraint logic → measurement/constraints.zig
  - Extract intrinsic sizing → measurement/intrinsic.zig
  - Create content measurement → measurement/content.zig
  - Create measurement/mod.zig with exports

  Phase 4: Arrangement Algorithms

  - Create src/lib/layout/arrangement/ directory
  - Extract flow algorithms → arrangement/flow.zig
  - Extract stacking/z-index → arrangement/stacking.zig
  - Move alignment logic → arrangement/alignment.zig
  - Create arrangement/mod.zig with exports

  Phase 5: Backend Abstraction

  - Create src/lib/layout/backends/ directory
  - Extract CPU backend from benchmark → backends/cpu.zig
  - Move gpu/mod.zig core → backends/gpu.zig
  - Move gpu/hybrid.zig → backends/hybrid.zig
  - Create backend interface → backends/interface.zig
  - Create backends/mod.zig with exports

  Phase 6: Animation System

  - Create src/lib/layout/animation/ directory
  - Extract spring physics → animation/springs.zig
  - Create transition system → animation/transitions.zig
  - Create easing functions → animation/easing.zig
  - Create animation/mod.zig with exports

  Phase 7: Debug Tools

  - Create src/lib/layout/debug/ directory
  - Move validator from benchmark → debug/validator.zig
  - Create profiler → debug/profiler.zig
  - Create visualizer → debug/visualizer.zig
  - Create debug/mod.zig with exports

  Phase 8: Text Integration

  - Create src/lib/layout/text_integration.zig
  - Move text baseline logic here
  - Remove dependency on ../text/layout.zig
  - Create clean text layout interface

  Phase 9: Core Algorithms

  - Create src/lib/layout/algorithms.zig
  - Extract reusable layout algorithms
  - Document algorithm complexity
  - Add algorithm selection logic

  Phase 10: Clean Up

  - Rewrite src/lib/layout/mod.zig with clean exports
  - Update all imports across codebase
  - Remove old GPU directory structure
  - Update documentation

  Testing Strategy

  - Test each module in isolation before moving
  - Ensure benchmark still works after each phase
  - Run full test suite after each phase
  - Create new tests for extracted modules

  Success Criteria

  - Each module has a single, clear responsibility
  - No circular dependencies between modules
  - Improved compile times due to better separation
  - Easier to understand and navigate codebase
  - All existing functionality preserved

  Notes

  - Keep changes incremental and testable
  - Preserve existing APIs where possible
  - Document breaking changes clearly
  - Consider performance implications of abstractions