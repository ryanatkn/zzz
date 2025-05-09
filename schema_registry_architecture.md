# Schema and Action Registry Architecture

## Current Architecture

The codebase currently implements a type-safe way to define and use action schemas, but has several limitations:

- It relies on global variables for registration
- It has potential for circular dependencies
- No clean way to extend or modify schemas at runtime
- Naming conventions could be improved

## New Registry-Based Architecture

### Key Components

1. **Schema Registry**

   - Centralized store for all Zod schemas
   - Provides lookup by name and groups schemas by category
   - Supports reverse lookup (schema to name)

2. **Action Registry**

   - Specialized registry for action specifications
   - Tracks client vs. server actions
   - Provides direction information and spec lookup

3. **Zzz Registry**
   - Combines Schema and Action registries
   - Available via Svelte context on client
   - Instantiated directly on server

### Benefits

- **No Circular Dependencies**: Clean separation between schemas and action types
- **Runtime Flexibility**: Schemas can be modified, extended, or replaced at runtime
- **Better Organization**: Grouped schemas and clear naming conventions
- **Type Safety**: Full TypeScript type checking preserved
- **SvelteKit Integration**: Available via context in components
- **Testability**: Can create separate registry instances for testing

## Implementation Roadmap

### Phase 1: File Structure and Generation

1. ✅ Split action types and collections
2. ✅ Improve naming conventions
3. ✅ Add proper case conversion helpers
4. ✅ Create registry classes

### Phase 2: Integration

1. Initialize the registry on server startup
2. Set up Svelte context for client-side access
3. Update import patterns to avoid circular dependencies
4. Replace global variables with registry lookups

### Phase 3: Enhanced Features

1. Add schema extension support
2. Implement versioning for schemas
3. Create debug and introspection tools
4. Add schema validation middleware

## Code Organization

```
lib/
├── action_types.gen.ts     # Generated action name enum and mapping interfaces
├── action_types.ts         # Action type definitions (no imports from schemas)
├── action_collections.gen.ts # Generated collections of actions (imports schemas)
├── schemas.ts              # Schema definitions using Zod
├── schema_helpers.ts       # Helper functions for schema manipulation
├── schema_registry.svelte.ts # Registry classes
└── schema_metadata.ts      # Schema metadata (to be replaced by registry)
```

## Design Principles

1. **Separation of Concerns**:

   - `action_types.ts` should not import from `schemas.ts`
   - `schemas.ts` can import from `action_types.ts`
   - Collections can import from both

2. **Late Binding**:

   - Use registry for runtime lookups
   - Allow schemas to be modified at runtime

3. **Type Safety**:

   - Preserve full TypeScript type checking
   - Use zod for runtime validation

4. **Extensibility**:
   - Registry should support adding new schemas
   - Support for schema versioning and evolution

## Migration Path

1. Create generators for `action_types.ts` and `action_collections.ts`
2. Update imports to avoid circular dependencies
3. Implement registry classes
4. Gradually replace global variables with registry lookups
5. Update server and client code to use registries

This approach provides a more flexible system while maintaining type safety and avoiding circular dependencies.
