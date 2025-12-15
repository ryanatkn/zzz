# Development Guide

⚠️ AI generated

Development workflow, extension points, and common patterns for Zzz.

## Contents

- [Setup](#setup)
- [Development Workflow](#development-workflow)
- [Project Structure](#project-structure)
- [Extension Points](#extension-points)
- [Common Patterns](#common-patterns)
- [Testing](#testing)
- [Code Style](#code-style)

## Setup

### Prerequisites

- Node.js 20+
- npm

### Initial Setup

```bash
# Clone repository
git clone https://github.com/ryanatkn/zzz.git
cd zzz

# Copy environment template
cp src/lib/server/.env.development.example .env.development

# Install dependencies
npm install

# Start development server
gro dev
```

### Environment Variables

Configure in `.env.development`:

```bash
# AI Provider API Keys (BYOK - Bring Your Own Key)
SECRET_ANTHROPIC_API_KEY=sk-ant-...
SECRET_OPENAI_API_KEY=sk-...
SECRET_GOOGLE_API_KEY=AIza...

# Server Configuration
PUBLIC_ZZZ_DIR=./           # Base for .zzz directory
ALLOWED_ORIGINS=http://localhost:5173,http://localhost:3000
```

## Development Workflow

### Commands

| Command | Description |
|---------|-------------|
| `gro dev` | Start dev server with HMR |
| `gro build` | Production build |
| `gro test` | Run tests |
| `gro test -- --watch` | Run tests in watch mode |
| `gro typecheck` | TypeScript type checking |
| `gro check` | Run all checks (types, lint, test) |
| `gro lint` | ESLint checking |
| `gro gen` | Run code generation |
| `gro deploy` | Deploy to production |

### Code Generation

Some files are auto-generated from specs:

```bash
gro gen
```

Generated files (do not edit manually):
- `src/lib/action_metatypes.gen.ts` - Action method types
- `src/lib/action_collections.gen.ts` - Action spec collections
- `src/lib/frontend_action_types.gen.ts` - Frontend handler types
- `src/lib/server/backend_action_types.gen.ts` - Backend handler types

### Build Output

```
build/                   # SvelteKit build output
dist/                    # Library distribution
.zzz/                    # Zzz directory (runtime data)
```

## Project Structure

### Key Directories

```
src/
├── lib/                 # Core library (published as @ryanatkn/zzz)
│   ├── server/         # Backend code
│   └── ...             # Shared code (frontend + backend)
├── routes/             # SvelteKit pages
└── app.html            # HTML template
```

### File Naming

| Pattern | Purpose | Example |
|---------|---------|---------|
| `*.ts` | TypeScript modules | `helpers.ts` |
| `*.svelte.ts` | Svelte 5 reactive modules | `chat.svelte.ts` |
| `*.svelte` | Svelte components | `ChatView.svelte` |
| `*.test.ts` | Test files | `cell.test.ts` |
| `*_types.ts` | Type definitions | `action_types.ts` |
| `*_helpers.ts` | Utility functions | `jsonrpc_helpers.ts` |

### Component Naming

Components use `PascalCase` with domain prefixes:

| Prefix | Domain | Examples |
|--------|--------|----------|
| `Chat` | Chat UI | `ChatView`, `ChatListitem` |
| `Diskfile` | File editor | `DiskfileEditorView`, `DiskfileExplorer` |
| `Model` | Model management | `ModelListitem`, `ModelPickerDialog` |
| `Ollama` | Ollama-specific | `OllamaManager`, `OllamaPullModel` |
| `Part` | Content parts | `PartView`, `PartEditorForText` |
| `Prompt` | Prompts | `PromptList`, `PromptPickerDialog` |
| `Thread` | Threads | `ThreadList`, `ThreadContextmenu` |
| `Turn` | Turns | `TurnView`, `TurnListitem` |

## Extension Points

### Adding a New Cell

1. **Define the schema** (`src/lib/my_thing_types.ts`):

```typescript
import {z} from 'zod';
import {CellJson} from './cell_types.js';

export const MyThingJson = CellJson.extend({
  name: z.string().default(''),
  value: z.number().default(0),
}).meta({cell_class_name: 'MyThing'});
```

2. **Create the class** (`src/lib/my_thing.svelte.ts`):

```typescript
import {Cell, type CellOptions} from './cell.svelte.js';
import {MyThingJson} from './my_thing_types.js';

export interface MyThingOptions extends CellOptions<typeof MyThingJson> {}

export class MyThing extends Cell<typeof MyThingJson> {
  name: string = $state()!;
  value: number = $state()!;

  readonly doubled = $derived(this.value * 2);

  constructor(options: MyThingOptions) {
    super(MyThingJson, options);
    this.init();
  }

  increment(): void {
    this.value++;
  }
}
```

3. **Register the class** (in `frontend.svelte.ts`):

```typescript
this.cell_registry.register(MyThing);
```

### Adding a New Action

1. **Define the spec** (`src/lib/action_specs.ts`):

```typescript
export const my_action_spec = create_action_spec({
  method: 'my_action',
  kind: 'request_response',
  initiator: 'frontend',
  auth: 'authorize',
  side_effects: true,
  async: true,
  input: z.object({
    message: z.string(),
  }),
  output: z.object({
    result: z.string(),
  }),
});
```

2. **Add to exports** (`src/lib/action_specs.ts`):

```typescript
export const action_specs = [
  // ... existing specs
  my_action_spec,
];
```

3. **Run code generation**:

```bash
gro gen
```

4. **Add frontend handler** (`src/lib/frontend_action_handlers.ts`):

```typescript
my_action: {
  send_request: ({data}) => {
    console.log('Sending:', data.input.message);
  },
  receive_response: ({app, data}) => {
    console.log('Received:', data.output.result);
  },
  receive_error: ({data}) => {
    console.error('Error:', data.error);
  },
},
```

5. **Add backend handler** (`src/lib/server/backend_action_handlers.ts`):

```typescript
my_action: {
  receive_request: async ({backend, data}) => {
    const {message} = data.input;
    // Process the request
    return {result: `Processed: ${message}`};
  },
},
```

### Adding a New Route

1. **Create route directory** (`src/routes/my_route/`):

```
src/routes/my_route/
├── +page.svelte
└── +page.ts (optional)
```

2. **Create page component** (`+page.svelte`):

```svelte
<script lang="ts">
  import {frontend_context} from '$lib/frontend.svelte.js';

  const app = frontend_context.get();
</script>

<h1>My Route</h1>
<!-- page content -->
```

### Adding a Component

1. **Create component** (`src/lib/MyComponent.svelte`):

```svelte
<script lang="ts">
  import type {Snippet} from 'svelte';

  interface Props {
    title: string;
    children?: Snippet;
  }

  const {title, children}: Props = $props();
</script>

<div class="my-component">
  <h2>{title}</h2>
  {#if children}
    {@render children()}
  {/if}
</div>
```

## Common Patterns

### State Access

```svelte
<script lang="ts">
  import {frontend_context} from '$lib/frontend.svelte.js';

  const app = frontend_context.get();

  // Access collections
  const {chats, models, prompts} = app;

  // Derived state
  const selected_chat = $derived(chats.selected);
</script>
```

### Collection Operations

```typescript
// Add item
const chat = app.chats.add({name: 'New Chat'});

// Get by ID
const chat = app.chats.items.by_id.get(id);

// Get by index
const model = app.models.items.by('name', 'gpt-4');

// Query multi-index
const ollama_models = app.models.items.where('provider_name', 'ollama');

// Iterate
for (const chat of app.chats.items.values) {
  console.log(chat.name);
}
```

### Action Invocation

```typescript
// Request/response action
const result = await app.api.completion_create({
  completion_request: {...},
  _meta: {progressToken: turn.id},
});

if (result.ok) {
  const {completion_response} = result.value;
} else {
  console.error(result.error);
}

// Local action (sync)
app.api.toggle_main_menu();
```

### Reactive Effects

```svelte
<script lang="ts">
  // Effect that runs when dependencies change
  $effect(() => {
    console.log('Selected chat changed:', app.chats.selected?.name);
  });

  // Pre-effect (runs before DOM updates)
  $effect.pre(() => {
    // URL synchronization, etc.
  });
</script>
```

### Context Menus

```svelte
<script lang="ts">
  import Contextmenu from '@fuzdev/fuz_ui/Contextmenu.svelte';
  import ContextmenuEntry from '@fuzdev/fuz_ui/ContextmenuEntry.svelte';
</script>

<Contextmenu>
  {#snippet entries()}
    <ContextmenuEntry onclick={() => doSomething()}>
      Action Label
    </ContextmenuEntry>
  {/snippet}

  <!-- Wrapped content -->
  <div>Right-click me</div>
</Contextmenu>
```

### Dialog Pattern

```svelte
<script lang="ts">
  import PickerDialog from '$lib/PickerDialog.svelte';

  let show = $state(false);

  function handle_pick(item: Item): void {
    // Handle selection
    show = false;
  }
</script>

<button onclick={() => show = true}>Open Picker</button>

<PickerDialog
  bind:show
  items={collection.values}
  onpick={handle_pick}
>
  {#snippet children(item, pick)}
    <button onclick={() => pick(item)}>
      {item.name}
    </button>
  {/snippet}
</PickerDialog>
```

## Testing

### Running Tests

```bash
# Run all tests
gro test

# Watch mode
gro test -- --watch

# Specific file
gro test -- src/lib/cell.test.ts
```

### Writing Tests

```typescript
import {test} from 'uvu';
import * as assert from 'uvu/assert';

import {MyThing} from './my_thing.svelte.js';

test('MyThing initializes correctly', () => {
  const thing = new MyThing({app: mock_app, json: {name: 'test'}});
  assert.is(thing.name, 'test');
  assert.is(thing.value, 0);  // default
});

test('MyThing.increment works', () => {
  const thing = new MyThing({app: mock_app, json: {}});
  thing.increment();
  assert.is(thing.value, 1);
});

test.run();
```

## Code Style

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Variables/functions | `snake_case` | `send_message`, `user_input` |
| Classes | `PascalCase` | `ChatView`, `ActionPeer` |
| Types/interfaces | `PascalCase` | `ChatOptions`, `ActionSpec` |
| Constants | `SCREAMING_SNAKE_CASE` | `DEFAULT_TIMEOUT`, `API_PATH` |
| Private fields | `#field` | `#internal_state` |
| Zod schemas | `PascalCase` | `ChatJson`, `ActionSpec` |

### Code Quality Markers

```typescript
// @slop [Model] - LLM-generated code needing review
// TODO - Work to be done
// TODO @many - Affects multiple locations
// TODO @api - API design consideration
// TODO @db - Database-related
```

### Import Order

1. External packages (`svelte`, `zod`, etc.)
2. Internal aliases (`$lib/...`, `$routes/...`)
3. Relative imports (`./...`)

```typescript
import {z} from 'zod';
import {SvelteMap} from 'svelte/reactivity';

import {Cell} from '$lib/cell.svelte.js';
import type {Frontend} from '$lib/frontend.svelte.js';

import {helper_function} from './helpers.js';
```

### Svelte 5 Runes

```typescript
// Reactive state
name: string = $state()!;           // Initialized by Cell.init()
count: number = $state(0);          // With default

// Derived values
readonly doubled = $derived(this.count * 2);
readonly complex = $derived.by(() => {
  // Complex computation
  return expensiveCalculation(this.count);
});

// Raw state (no deep reactivity)
response: Response = $state.raw();
```

### Error Handling

```typescript
// Return Result type for actions
const result = await app.api.some_action(input);
if (!result.ok) {
  console.error('Action failed:', result.error);
  return;
}
const {value} = result;

// Throw for unexpected errors
if (!expectedCondition) {
  throw new Error('Unexpected state');
}

// Use ThrownJsonrpcError for structured errors
throw new ThrownJsonrpcError(
  jsonrpc_error_messages.invalid_params('Missing required field'),
);
```
