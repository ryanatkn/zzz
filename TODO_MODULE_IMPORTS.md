# TODO: Fix Zig Module Import Strategy

**Status:** Build fails due to module path restrictions

**Problem:**
```
error: import of file outside module path: '../../../lib/browser/page.zig'
```

**Root Cause:**
Cross-module relative imports violate Zig's module boundary restrictions when `src/hex/hud/router.zig` imports `src/roots/menu/+layout.zig` which tries to import `../../../lib/browser/page.zig`.

**Solutions to Evaluate:**
1. **Absolute imports** - Use project root paths instead of relative
2. **Build.zig modules** - Define explicit module boundaries  
3. **Import restructure** - Avoid cross-module boundaries
4. **Zig module patterns** - Follow official multi-directory patterns

**Architecture Success:**
✅ Separated reusable (`src/lib/browser/`) from hex-specific (`src/hex/hud/`)  
✅ Clean component boundaries maintained  
✅ Engine/game separation preserved

**Next Steps:**
Test solution approaches, prioritize minimal changes to working architecture.