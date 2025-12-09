# Architecture

⚠️ AI generated

Deep dive into Zzz's core systems: actions, cells, content model, and data flow.

## Contents

- [Action System](#action-system)
- [Cell System](#cell-system)
- [Content Model](#content-model)
- [Data Flow](#data-flow)
- [IndexedCollection](#indexedcollection)

## Action System

The action system provides **symmetric, peer-to-peer RPC** - the same code runs on frontend and backend.

### Core Components

| Component | Purpose | File |
|-----------|---------|------|
| `ActionSpec` | Defines action metadata (method, kind, schemas) | `action_spec.ts` |
| `ActionEvent` | Lifecycle state machine | `action_event.ts` |
| `ActionPeer` | Send/receive operations | `action_peer.ts` |
| `ActionRegistry` | Type-safe action lookup | `action_registry.ts` |

### Action Specification

Every action is defined with a spec:

```typescript
export const completion_create_action_spec = {
  method: 'completion_create',
  kind: 'request_response',        // or 'remote_notification', 'local_call'
  initiator: 'frontend',           // or 'backend', 'both'
  auth: 'authorize',               // or 'public', null
  side_effects: true,              // or null
  async: true,
  input: z.object({
    completion_request: CompletionRequest,
    _meta: z.object({ progressToken: Uuid.optional() }).optional(),
  }),
  output: z.object({
    completion_response: CompletionResponse,
  }),
};
```

### Action Kinds

**`request_response`**: Traditional RPC pattern
- Frontend sends request → Backend handles → Backend sends response
- Phases: `send_request` → `receive_request` → `send_response` → `receive_response`

**`remote_notification`**: Fire-and-forget (backend → frontend)
- Used for streaming progress updates
- Phases: `send` → `receive`

**`local_call`**: Frontend-only
- No network transport
- Phase: `execute`

### Action Event Lifecycle

Each action goes through a state machine:

```
Steps:   initial → parsed → handling → handled (or failed)
Phases:  send_request ↔ receive_request ↔ send_response ↔ receive_response
```

```typescript
// Creating and executing an action
const event = create_action_event(environment, spec, input, 'send_request');
await event.parse().handle_async();
```

### Handler Registration

Frontend and backend register handlers for each action/phase:

```typescript
// Frontend handler (frontend_action_handlers.ts)
export const frontend_action_handlers = {
  completion_create: {
    send_request: ({data}) => {
      console.log('Sending completion request');
    },
    receive_response: ({app, data}) => {
      const {completion_response} = data.output;
      // Update turn with response
    },
    receive_error: ({data}) => {
      console.error('Completion failed:', data.error);
    },
  },
};

// Backend handler (backend_action_handlers.ts)
export const backend_action_handlers = {
  completion_create: {
    receive_request: async ({backend, data}) => {
      const {completion_request} = data.input;
      const provider = backend.lookup_provider(completion_request.provider_name);
      const response = await provider.handle_completion(options);
      return {completion_response: response};
    },
  },
};
```

### Transport Layer

Actions are transport-agnostic via the `Transport` interface:

```typescript
interface Transport {
  transport_name: TransportName;
  send(message: JsonrpcRequest): Promise<JsonrpcResponseOrError>;
  send(message: JsonrpcNotification): Promise<JsonrpcErrorMessage | null>;
  is_ready(): boolean;
}
```

**Implementations**:
- `FrontendHttpTransport`: HTTP requests to backend
- `FrontendWebsocketTransport`: WebSocket for bidirectional communication
- `BackendWebsocketTransport`: Server-side WebSocket handling

### JSON-RPC 2.0

Actions use JSON-RPC 2.0 (MCP-compatible subset, no batching):

```typescript
// Request
{ jsonrpc: "2.0", id: "uuid", method: "completion_create", params: {...} }

// Response
{ jsonrpc: "2.0", id: "uuid", result: {...} }

// Error
{ jsonrpc: "2.0", id: "uuid", error: { code: -32000, message: "..." } }

// Notification (no id, no response)
{ jsonrpc: "2.0", method: "completion_progress", params: {...} }
```

### All Actions

Defined in `src/lib/action_specs.ts`:

| Action | Kind | Initiator | Purpose |
|--------|------|-----------|---------|
| `ping` | request_response | both | Health check |
| `session_load` | request_response | frontend | Load initial session |
| `completion_create` | request_response | frontend | AI completion |
| `completion_progress` | remote_notification | backend | Streaming chunks |
| `diskfile_update` | request_response | frontend | Update file |
| `diskfile_delete` | request_response | frontend | Delete file |
| `directory_create` | request_response | frontend | Create directory |
| `filer_change` | remote_notification | backend | File change notification |
| `ollama_*` | request_response | frontend | Ollama model management |
| `provider_load_status` | request_response | frontend | Check provider availability |
| `provider_update_api_key` | request_response | frontend | Update API key |
| `toggle_main_menu` | local_call | frontend | UI toggle |

## Cell System

Cells are **schema-driven reactive data models** using Svelte 5 runes.

### Base Cell Class

```typescript
export abstract class Cell<TSchema extends z.ZodType> {
  // Identity
  readonly id: Uuid = $state()!;
  readonly created: Datetime = $state()!;
  updated: Datetime = $state()!;

  // Schema
  readonly schema: TSchema;
  readonly schema_keys: Array<string> = $derived(...);

  // JSON operations
  readonly json = $derived(this.to_json());
  set_json(json: z.input<TSchema>): void;
  set_json_partial(partial: Partial<...>): void;

  // Lifecycle
  init(): void;  // Call at end of constructor
  dispose(): void;

  // Registry
  register(): void;
  unregister(): void;
}
```

### Creating a Cell

```typescript
// 1. Define schema
export const ChatJson = CellJson.extend({
  name: z.string().default(''),
  thread_ids: z.array(Uuid).default(() => []),
  view_mode: z.enum(['simple', 'multi']).default('simple'),
}).meta({cell_class_name: 'Chat'});

// 2. Create class
export class Chat extends Cell<typeof ChatJson> {
  // Reactive properties
  name: string = $state()!;
  thread_ids: Array<Uuid> = $state()!;
  view_mode: ChatViewMode = $state()!;

  // Derived properties
  readonly threads: Array<Thread> = $derived.by(() =>
    this.thread_ids.map(id => this.app.threads.items.by_id.get(id)).filter(Boolean)
  );

  constructor(options: ChatOptions) {
    super(ChatJson, options);
    this.init();  // Must call at end
  }
}
```

### Cell Options

```typescript
interface CellOptions<TSchema extends z.ZodType> {
  app: Frontend;                    // Reference to root state
  json?: z.input<TSchema>;          // Initial JSON data
}
```

### Custom Decoders

For complex field deserialization:

```typescript
constructor(options: ThreadOptions) {
  super(ThreadJson, options);

  this.decoders = {
    turns: (items) => {
      if (Array.isArray(items)) {
        this.turns.clear();
        for (const json of items) {
          this.add_turn(json);
        }
      }
      return HANDLED;  // Signal full handling
    },
  };

  this.init();
}
```

### Cell Registry

All cells auto-register by ID, enabling reflection:

```typescript
// Register a class
app.cell_registry.register(Chat);

// Instantiate from JSON
const chat = app.cell_registry.instantiate('Chat', json);

// Lookup by ID
const cell = app.cell_registry.all.get(id);
```

## Content Model

### Hierarchy

```
Frontend (root)
├── Chats (collection)
│   └── Chat
│       └── thread_ids → Thread[]
├── Threads (collection)
│   └── Thread
│       └── turns: IndexedCollection<Turn>
├── Parts (collection)
│   ├── TextPart (content stored directly)
│   └── DiskfilePart (content from file)
└── Prompts (collection)
    └── Prompt
        └── parts: Array<Part>
```

### Parts

Content units that can be shared:

**TextPart**: Direct content storage
```typescript
class TextPart extends Part<typeof TextPartJson> {
  readonly type = 'text';
  content: string = $state()!;
}
```

**DiskfilePart**: File reference with lazy loading
```typescript
class DiskfilePart extends Part<typeof DiskfilePartJson> {
  readonly type = 'diskfile';
  path: DiskfilePath | null = $state()!;

  // Content from file (or editor state if editing)
  get content(): string | null | undefined {
    return this.#editor_state?.current_content ?? this.diskfile?.content;
  }
}
```

### Turns

Conversation messages with role context:

```typescript
class Turn extends Cell<typeof TurnJson> {
  part_ids: Array<Uuid> = $state()!;
  role: CompletionRole = $state()!;  // 'user' | 'assistant' | 'system'
  request: CompletionRequest | undefined = $state.raw();
  response: CompletionResponse | undefined = $state.raw();

  // Aggregated content from all parts
  readonly content: string = $derived(
    this.parts.map(p => p.content).filter(Boolean).join('\n\n')
  );

  // Pending when assistant turn awaits response
  readonly pending: boolean = $derived(
    this.role === 'assistant' && this.is_content_empty && !this.response
  );
}
```

### Threads

Linear conversation with a model:

```typescript
class Thread extends Cell<typeof ThreadJson> {
  model_name: string = $state()!;
  readonly model: Model = $derived.by(() => this.app.models.find_by_name(this.model_name));

  readonly turns: IndexedCollection<Turn> = new IndexedCollection();
  enabled: boolean = $state()!;

  async send_message(content: string): Promise<Turn | null> {
    const user_turn = this.add_user_turn(content);
    const assistant_turn = this.add_assistant_turn('', {request: ...});

    await this.app.api.completion_create({
      completion_request,
      _meta: {progressToken: assistant_turn.id},
    });

    return assistant_turn;
  }
}
```

### Chats

Container for multi-model comparison:

```typescript
class Chat extends Cell<typeof ChatJson> {
  name: string = $state()!;
  thread_ids: Array<Uuid> = $state()!;
  view_mode: ChatViewMode = $state()!;  // 'simple' | 'multi'

  readonly threads: Array<Thread> = $derived.by(...);
  readonly enabled_threads: Array<Thread> = $derived(...);

  async send_to_all(content: string): Promise<void> {
    await Promise.all(this.enabled_threads.map(t => t.send_message(content)));
  }
}
```

### Prompts

Reusable content templates:

```typescript
class Prompt extends Cell<typeof PromptJson> {
  name: string = $state()!;
  parts: Array<PartUnion> = $state()!;

  readonly content: string = $derived(format_prompt_content(this.parts));
}
```

## Data Flow

### Completion Request Flow

```
User types message in Chat UI
    ↓
Chat.send_to_thread(content)
    ↓
Thread.send_message(content)
    ├── Create user Turn with TextPart
    ├── Build CompletionMessage[] from thread history
    ├── Create empty assistant Turn (progressToken = turn.id)
    └── Call app.api.completion_create(request)
    ↓
ActionEvent lifecycle (send_request phase)
    ↓
Transport.send(JSON-RPC request)
    ↓
Backend.peer.receive(message)
    ↓
ActionEvent lifecycle (receive_request phase)
    ↓
backend_action_handlers.completion_create.receive_request()
    ├── Lookup provider
    ├── Call provider.handle_streaming_completion()
    │   └── For each chunk: backend.api.completion_progress({token, chunk})
    └── Return {completion_response}
    ↓
ActionEvent lifecycle (send_response phase)
    ↓
JSON-RPC response → Transport
    ↓
Frontend receives response
    ↓
ActionEvent lifecycle (receive_response phase)
    ↓
frontend_action_handlers.completion_create.receive_response()
    └── turn.content = response_text, turn.response = completion_response
    ↓
Svelte reactivity updates UI
```

### Streaming Progress Flow

```
Backend provider iterates chunks
    ↓
provider.send_streaming_progress(progressToken, chunk)
    ↓
backend.api.completion_progress({progressToken, chunk})
    ↓
create_action_event(spec, input, 'send')
    ↓
event.parse().handle_async()
    ↓
backend.peer.send(notification)  // JSON-RPC notification (no id)
    ↓
WebSocket broadcast to all clients
    ↓
Frontend.peer.receive(notification)
    ↓
frontend_action_handlers.completion_progress.receive()
    └── Find turn by progressToken, append chunk to content
    ↓
Turn.content updates → UI re-renders
```

## IndexedCollection

Efficient queryable collections with multiple index types.

### Structure

```typescript
class IndexedCollection<T extends IndexedItem> {
  readonly by_id: SvelteMap<Uuid, T> = new SvelteMap();
  readonly values: Array<T> = $derived(Array.from(this.by_id.values()));
  readonly size: number = $derived(this.by_id.size);
  readonly indexes: Record<string, any> = $state({});
}
```

### Index Types

**Single Index**: One key → one item
```typescript
create_single_index({
  key: 'name',
  extractor: (model) => model.name,
})
// Usage: collection.by('name', 'gpt-4')
```

**Multi Index**: One key → many items
```typescript
create_multi_index({
  key: 'provider_name',
  extractor: (model) => model.provider_name,
  sort: (a, b) => a.name.localeCompare(b.name),
})
// Usage: collection.where('provider_name', 'ollama')
```

**Derived Index**: Computed array
```typescript
create_derived_index({
  key: 'ordered_by_name',
  compute: (collection) => collection.values,
  sort: (a, b) => a.name.localeCompare(b.name),
})
// Usage: collection.derived_index('ordered_by_name')
```

### Incremental Updates

Indexes support incremental onadd/onremove:

```typescript
{
  key: 'by_tag',
  type: 'multi',
  extractor: (model) => model.tags,
  onadd: (index, item) => {
    for (const tag of item.tags) {
      const arr = index.get(tag) || [];
      arr.push(item);
      index.set(tag, arr);
    }
    return index;
  },
  onremove: (index, item) => {
    for (const tag of item.tags) {
      const arr = index.get(tag) || [];
      const idx = arr.indexOf(item);
      if (idx >= 0) arr.splice(idx, 1);
    }
    return index;
  },
}
```

### Usage Example

```typescript
// In Models collection
export class Models extends Cell<typeof ModelsJson> {
  readonly items: IndexedCollection<Model> = new IndexedCollection({
    indexes: [
      create_single_index({key: 'name', extractor: m => m.name}),
      create_multi_index({key: 'provider_name', extractor: m => m.provider_name}),
      create_multi_index({key: 'tag', extractor: m => m.tags}),
      create_derived_index({key: 'ordered_by_name', sort: (a, b) => a.name.localeCompare(b.name)}),
    ],
  });

  find_by_name(name: string): Model | undefined {
    return this.items.by_optional('name', name);
  }

  filter_by_provider(provider: string): Array<Model> {
    return this.items.where('provider_name', provider);
  }
}
```
