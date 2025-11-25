# Zzz - LLM Agent Guide

## Core values

- User agency and control over tools and data
- Fullstack unification with single TypeScript runtime
- Protocol agnosticism with broad compatibility goals
- Extensibility without prescription
- Open standards and interoperability

## Overview

Zzz (pronounced "zees") is a fullstack web toolkit for power users and developers, combining LLM UI capabilities, file editing, and extensible web platform features. It provides both a customizable web UI for power users and a flexible toolkit for building UX-maximizing websites. Future plans include expanded IDE features like terminal access.

**Status**: Early pre-release, development use only (no auth yet)

## Architecture

### Action system

The action system is **symmetric and peer-to-peer**, running the same code in any environment. Both frontend and backend use `ActionPeer` for send/receive operations. Actions and handlers (queries and side effects) are abstracted into declarative configuration, enabling flexible communication patterns without coupling to client/server roles.

#### Key components:

- `ActionPeer`: Manages send/receive for both frontend and backend
- `ActionEvent`: Lifecycle management with phases (init → send → receive → complete)
- `ActionRegistry`: Type-safe action registration
- `ActionSpec`: Defines action metadata (kind, initiator, auth, side_effects)

#### Action kinds:

- `request_response`: Traditional RPC pattern
- `remote_notification`: Fire-and-forget messages from backend
- `local_call`: Frontend-only calls

#### Transport layer:

- Abstract `Transport` interface supporting multiple implementations
- `FrontendHttpTransport` and `FrontendWebsocketTransport` for client
- `BackendWebsocketTransport` for server WebSocket handling
- Automatic fallback between transports when configured

### Protocol strategy

Zzz uses JSON-RPC 2.0 as its foundation with planned compatibility for:

- **MCP (Model Context Protocol)**: Subset of JSON-RPC, no batching
- **A2A (Agent2Agent)**: Google's agent communication protocol
- **OpenAI Completions API**: For broader AI service compatibility

Internal abstractions are designed as supersets that can map to these protocols, allowing broad interoperability while maintaining internal flexibility.

### State management

- **Reactive state**: Svelte 5 runes in `.svelte.ts` files
- **Cell system**: Base class for schema-driven reactive models with lifecycle
- **IndexedCollection**: Queryable collections with multiple index types
- **CellRegistry**: Runtime type registration and instantiation

## Tech stack

### Core technologies

- **Frontend**: SvelteKit + TypeScript + Vite + Svelte 5
- **Backend**: Hono server + Node.js runtime
- **Build**: @ryanatkn/gro toolkit
- **UI**: @ryanatkn/fuz components, @ryanatkn/moss styling
- **Validation**: Zod schemas throughout

### Key dependencies

- `@ryanatkn/gro`: Build tooling and development utilities
- `@ryanatkn/fuz`: UI component library
- `@ryanatkn/moss`: CSS framework and theming
- `@ryanatkn/belt`: Utility functions
- `hono`: Web server framework
- `zod`: Schema validation

## Directory structure

### src/lib/ (published as @ryanatkn/zzz)

```
src/lib/
├── server/                    # Backend functionality
│   ├── backend.ts            # Core backend class
│   ├── backend_action_*.ts   # Action handling
│   ├── *_backend_provider.ts # AI provider implementations
│   ├── scoped_fs.ts          # Secure filesystem access
│   ├── security.ts           # Origin verification, access control
│   └── server.ts             # Hono server setup
│
├── *.svelte.ts               # Reactive state classes
│   ├── frontend.svelte.ts    # Main frontend state
│   ├── cell.svelte.ts        # Base reactive model
│   ├── chat.svelte.ts        # Chat state
│   ├── thread.svelte.ts      # Thread state
│   ├── turn.svelte.ts        # Turn state
│   ├── part.svelte.ts        # Part state
│   ├── model.svelte.ts       # AI model state
│   └── diskfile.svelte.ts    # File state
│
├── action_*.ts               # Action system core
│   ├── action_event.ts       # Event lifecycle
│   ├── action_peer.ts        # Peer communication
│   ├── action_registry.ts    # Type registration
│   └── action_spec.ts        # Action metadata
│
├── *.svelte        # UI components (Upper_Snake_Case)
│   ├── Chat_*.svelte         # Chat components
│   ├── Diskfile_*.svelte     # File components
│   ├── Model_*.svelte        # Model components
│   └── Ollama_*.svelte       # Ollama-specific
│
└── *.ts                      # Core utilities
    ├── jsonrpc.ts            # JSON-RPC implementation
    ├── transports.ts         # Transport abstraction
    └── constants.ts          # Configuration
```

### src/routes/ (SvelteKit routes)

Key routes include:

- `/chats` - Chat interface with AI models
- `/prompts` - Prompt builder and management
- `/models` - Model configuration
- `/files` - File editor (IDE-like functionality)
- `/providers` - Provider configuration
- `/actions` - View all action specs (see `src/lib/action_specs.ts`)

All actions are declared in `src/lib/action_specs.ts` with full type definitions.

## Core patterns

### Naming conventions

- **TS files and Svelte 5 TS modules**: `snake_case.ts`, `snake_case.svelte.ts`
- **Svelte components**: `Upper_Snake_Case.svelte` (e.g., `ChatView`, `DiskfileEditor`)
- **Actions**: `action_method_name` in collections
- **Tests**: `module_name.test.ts` alongside implementation

### Component organization

Components are prefixed by domain:

- `Chat_*`: Chat/conversation UI
- `Diskfile_*`: File management UI
- `Model_*`: AI model UI
- `Ollama_*`: Ollama-specific UI
- `Part_*`: Content part UI
- `Prompt_*`: Prompt management UI
- `Thread_*`: Conversation thread UI
- `Turn_*`: Conversation turn UI

### State patterns

```typescript
// State class with schema
export class MyThing extends Cell<typeof MyThing_Json> {
	// Reactive properties use Svelte 5 runes
	value = $state(0);
	derived = $derived(this.value * 2);
}

// Companion Zod schema
export const MyThing_Json = CellJson.extend({
	value: z.number(),
});
```

### Code quality markers

- `// @slop [Model]`: Marks LLM-generated code for review
- Test files may contain LLM-generated tests
- Core interfaces are hand-crafted, implementations may use LLM assistance

## Key abstractions

### Actions

Type-safe bidirectional RPC system:

- Defined via `ActionSpec` with metadata
- Handled by registered `ActionHandlers`
- Lifecycle managed by `ActionEvent`
- Transport-agnostic via `Transport` interface

### Cells

Schema-driven reactive data models:

- Base class for all stateful entities
- Automatic JSON serialization/deserialization
- Lifecycle hooks (init, dispose)
- Type-safe property access via Zod schemas

### Collections

- **IndexedCollection**: Queryable collections with indexing
- **Models/Chats/Prompts/etc**: Domain-specific collections extending base patterns

### Content types

Zzz's content architecture enables flexible composition with A2A protocol compatibility:

- **Parts**: Reusable content entities (`TextPart` for direct content, `DiskfilePart` for file references)
- **Turns**: Conversation turns that reference part IDs with role context (user/assistant/system)
- **Threads**: Ordered conversation threads with turns, model config, and enable/disable controls
- **Chats**: UI containers with multiple threads for model comparison
- **Prompts**: Reusable part collections for context composition

Parts can be shared across multiple turns, enabling content reuse without duplication.

### AI providers

- **BackendProvider**: Base class for AI service integration
- Implementations: Ollama, Claude, ChatGPT, Gemini
- Unified completion interface
- Provider-specific configuration

## AI integration

### Provider architecture

```typescript
abstract class BackendProvider {
	abstract handle_streaming_completion(options: CompletionHandlerOptions): Promise<...>;
	abstract handle_non_streaming_completion(options: CompletionHandlerOptions): Promise<...>;
	get_handler(streaming: boolean): CompletionHandler;
}
```

### Supported providers

- **Ollama**: Local model execution (primary integration)
- **Claude**: Anthropic API (BYOK)
- **ChatGPT**: OpenAI API (BYOK)
- **Gemini**: Google AI API (BYOK)

### Configuration

- API keys via `.env.development`/`.env.production`
- Provider selection per chat/prompt
- Model configuration with defaults
- Streaming response support

## Security & deployment

### Filesystem Security

- **ScopedFs**: Restricts access to `.zzz` cache directory
- No symlink following
- Path traversal protection
- Configurable base directory via `PUBLIC_ZZZ_CACHE_DIR`

### Web security

- **CSP**: Strict Content Security Policy
- **CORS**: Origin-based access control via `ALLOWED_ORIGINS`
- **No Auth**: Currently development-only (auth planned)

### Deployment modes

- **Development**: `gro dev` with hot reload
- **Preview**: Static build via SvelteKit adapter-static
- **Production**: Node server (coming soon)

## Development

### Quick start

```bash
# Setup
cp src/lib/server/.env.development.example .env.development
npm install

# Development
gro dev          # or npm run dev

# Build & Test
gro build        # or npm run build
gro test         # or npm run test
gro typecheck    # or npm run typecheck
```

### Key commands

- `gro dev`: Start development server with HMR
- `gro build`: Production build
- `gro test`: Run test suite
- `gro typecheck`: Type checking
- `gro deploy`: Deploy to production

### Extension points

- **Custom Cells**: Extend `Cell` class with schemas
- **Action Handlers**: Register new actions via `ActionRegistry`
- **Providers**: Implement `BackendProvider` interface
- **Components**: Standard Svelte components
- **Routes**: SvelteKit file-based routing

## Project structure notes

### Circular dependencies

The architecture intentionally uses circular references between Frontend and App, managed via TypeScript's type system and runtime initialization patterns.

### Monolithic library

`src/lib/` is published as a single package to simplify versioning and dependencies, though internally it's well-organized by concern.

### Future directions

- Database integration (PostgreSQL via pglite)
- Authentication system
- Plugin API for npm-distributed extensions
- Full OpenAI API compatibility for broad remote AI API support
- MCP/A2A protocol implementation
- Enhanced terminal/system capabilities
- Migrate to Deno and publish with `deno compile`
