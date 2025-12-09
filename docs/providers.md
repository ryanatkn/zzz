# AI Providers

⚠️ AI generated

Guide to AI provider integration in Zzz, including adding new providers.

## Contents

- [Overview](#overview)
- [Supported Providers](#supported-providers)
- [Configuration](#configuration)
- [Provider Architecture](#provider-architecture)
- [Adding a New Provider](#adding-a-new-provider)
- [Completion Flow](#completion-flow)

## Overview

Zzz supports multiple AI providers through a unified interface:

- **Local**: Ollama (no API key required)
- **Remote**: Claude, ChatGPT, Gemini (BYOK - Bring Your Own Key)

All providers implement the same `BackendProvider` interface, enabling:
- Streaming and non-streaming completions
- Unified request/response format
- Provider-specific configuration
- Status checking and error handling

## Supported Providers

### Ollama (Local)

Local model execution via [Ollama](https://ollama.ai).

**Features**:
- No API key required
- Auto-pulls models if not installed
- Full streaming support
- Model management UI (`/providers/ollama`)

**Setup**:
1. Install Ollama: `curl -fsSL https://ollama.ai/install.sh | sh`
2. Start Ollama: `ollama serve`
3. Zzz auto-detects and shows available models

### Claude (Anthropic)

[Anthropic's Claude models](https://anthropic.com).

**Setup**:
```bash
# In .env.development
SECRET_ANTHROPIC_API_KEY=sk-ant-api03-...
```

**Supported Models**: claude-3-opus, claude-3-sonnet, claude-3-haiku, etc.

### ChatGPT (OpenAI)

[OpenAI's GPT models](https://openai.com).

**Setup**:
```bash
# In .env.development
SECRET_OPENAI_API_KEY=sk-...
```

**Supported Models**: gpt-4, gpt-4-turbo, gpt-3.5-turbo, o1-mini, etc.

**Note**: o1-mini doesn't support system messages.

### Gemini (Google)

[Google's Gemini models](https://ai.google.dev/).

**Setup**:
```bash
# In .env.development
SECRET_GOOGLE_API_KEY=AIza...
```

**Supported Models**: gemini-pro, gemini-pro-vision, etc.

## Configuration

### Environment Variables

```bash
# Provider API Keys
SECRET_ANTHROPIC_API_KEY=...
SECRET_OPENAI_API_KEY=...
SECRET_GOOGLE_API_KEY=...

# Can also be set via UI at /providers
```

### Completion Options

Configurable per-request or via defaults:

```typescript
interface CompletionOptions {
  frequency_penalty?: number;    // Reduce repetition
  output_token_max: number;      // Max response tokens
  presence_penalty?: number;     // Encourage new topics
  seed?: number;                 // Reproducibility
  stop_sequences?: string[];     // Stop generation at these
  system_message: string;        // System prompt
  temperature?: number;          // Randomness (0-2)
  top_k?: number;               // Top-k sampling
  top_p?: number;               // Nucleus sampling
}
```

### Provider Status

Check provider availability at runtime:

```typescript
const status = app.lookup_provider_status('ollama');
if (status?.available) {
  // Provider is ready
}
```

Status includes:
- `available`: Whether provider can accept requests
- `error_message`: Why unavailable (e.g., "API key required")
- `models`: Available models (for Ollama)

## Provider Architecture

### Class Hierarchy

```
BackendProvider<TClient>
├── BackendProviderLocal<TClient>
│   └── BackendProviderOllama (Ollama client)
└── BackendProviderRemote<TClient>
    ├── BackendProviderClaude (Anthropic client)
    ├── BackendProviderChatgpt (OpenAI client)
    └── BackendProviderGemini (GoogleGenerativeAI client)
```

### Base Class

```typescript
abstract class BackendProvider<TClient> {
  abstract readonly name: string;
  protected client: TClient | null = null;
  protected provider_status: ProviderStatus | null = null;

  // Completion handlers
  abstract handle_streaming_completion(options: CompletionHandlerOptions): Promise<CompletionResult>;
  abstract handle_non_streaming_completion(options: CompletionHandlerOptions): Promise<CompletionResult>;

  // Client management
  abstract create_client(): void;
  abstract get_client(): TClient;

  // Status
  abstract load_status(reload?: boolean): Promise<ProviderStatus>;
  invalidate_status(): void;

  // Get appropriate handler
  get_handler(streaming: boolean): CompletionHandler {
    return streaming
      ? this.handle_streaming_completion.bind(this)
      : this.handle_non_streaming_completion.bind(this);
  }
}
```

### Local vs Remote

**BackendProviderLocal**: For locally-installed services
- Creates client on construction
- `load_status()` checks if service is available

**BackendProviderRemote**: For API-based services
- Requires API key to create client
- `set_api_key()` updates key and recreates client
- Returns error status if no API key

### Completion Handler Options

```typescript
interface CompletionHandlerOptions {
  model: string;                              // Model name
  completion_options: CompletionOptions;      // Temperature, etc.
  completion_messages?: CompletionMessage[];  // Conversation history
  prompt: string;                             // Current user message
  progress_token?: Uuid;                      // For streaming updates
}
```

## Adding a New Provider

### 1. Create Provider Class

`src/lib/server/backend_provider_newprovider.ts`:

```typescript
import {NewProviderSDK} from 'newprovider-sdk';

import {BackendProviderRemote, type BackendProviderOptions} from './backend_provider.js';
import type {CompletionHandlerOptions, CompletionResult} from '../completion_types.js';

export class BackendProviderNewProvider extends BackendProviderRemote<NewProviderSDK> {
  readonly name = 'newprovider';

  constructor(options: BackendProviderOptions) {
    const api_key = process.env.SECRET_NEWPROVIDER_API_KEY;
    super({...options, api_key});
  }

  protected create_client(): void {
    if (!this.api_key) {
      this.client = null;
      return;
    }
    this.client = new NewProviderSDK({apiKey: this.api_key});
  }

  async handle_streaming_completion(options: CompletionHandlerOptions): Promise<CompletionResult> {
    const {model, prompt, completion_options, completion_messages, progress_token} = options;

    this.validate_streaming_requirements(progress_token);
    const client = this.get_client();

    // Format messages for provider SDK
    const messages = this.format_messages(completion_messages, prompt, completion_options);

    // Call provider with streaming
    const stream = await client.chat.completions.create({
      model,
      messages,
      stream: true,
      temperature: completion_options.temperature,
      max_tokens: completion_options.output_token_max,
    });

    let content = '';
    for await (const chunk of stream) {
      const delta = chunk.choices[0]?.delta?.content || '';
      content += delta;
      await this.send_streaming_progress(progress_token!, delta);
    }

    return {
      data: {provider: this.name, value: {content}},
    };
  }

  async handle_non_streaming_completion(options: CompletionHandlerOptions): Promise<CompletionResult> {
    const {model, prompt, completion_options, completion_messages} = options;
    const client = this.get_client();

    const messages = this.format_messages(completion_messages, prompt, completion_options);

    const response = await client.chat.completions.create({
      model,
      messages,
      temperature: completion_options.temperature,
      max_tokens: completion_options.output_token_max,
    });

    return {
      data: {provider: this.name, value: response},
    };
  }

  private format_messages(
    completion_messages: CompletionMessage[] | undefined,
    prompt: string,
    options: CompletionOptions,
  ) {
    const messages = [];

    if (options.system_message) {
      messages.push({role: 'system', content: options.system_message});
    }

    if (completion_messages) {
      for (const msg of completion_messages) {
        messages.push({role: msg.role, content: msg.content});
      }
    }

    messages.push({role: 'user', content: prompt});

    return messages;
  }
}
```

### 2. Register Provider

In `src/lib/server/server.ts`:

```typescript
import {BackendProviderNewProvider} from './backend_provider_newprovider.js';

// In server initialization
backend.add_provider(new BackendProviderNewProvider({backend, log}));
```

### 3. Add Response Helper

In `src/lib/response_helpers.ts`:

```typescript
export const to_completion_response_text = (response: CompletionResponse): string | undefined => {
  const {data} = response;
  switch (data.provider) {
    // ... existing cases
    case 'newprovider':
      return data.value?.content;
  }
};
```

### 4. Add Environment Variable

In `.env.development.example`:

```bash
SECRET_NEWPROVIDER_API_KEY=
```

### 5. Add Models

In `src/lib/default_models.ts`:

```typescript
{
  provider_name: 'newprovider',
  name: 'newprovider-model-1',
  tags: ['chat'],
},
```

## Completion Flow

### Request Flow

```
User sends message
    ↓
Thread.send_message(content)
    ↓
Create CompletionRequest:
  - provider_name: selected model's provider
  - model: model name
  - prompt: user message
  - completion_messages: thread history
    ↓
app.api.completion_create(request, {progressToken})
    ↓
Backend receives request
    ↓
backend.lookup_provider(provider_name)
    ↓
provider.get_handler(streaming=!!progressToken)
    ↓
provider.handle_[streaming/non_streaming]_completion()
```

### Streaming Flow

```
Provider calls SDK with stream: true
    ↓
For each chunk from stream:
    ├── Accumulate content
    └── provider.send_streaming_progress(progressToken, chunk)
            ↓
        backend.api.completion_progress({progressToken, chunk})
            ↓
        WebSocket notification to frontend
            ↓
        frontend_action_handlers.completion_progress.receive()
            ↓
        Turn.content updated incrementally
            ↓
        UI re-renders
    ↓
Return final CompletionResult
    ↓
Turn.response = completion_response
```

### Error Handling

```typescript
// In provider handler
async handle_streaming_completion(options) {
  try {
    // ... provider call
  } catch (error) {
    // Wrap provider errors
    throw new ThrownJsonrpcError(
      jsonrpc_error_messages.provider_error(this.name, error.message),
    );
  }
}

// Errors propagate to frontend handler
completion_create: {
  receive_error: ({data}) => {
    const turn = app.cell_registry.all.get(data.request?.params?._meta?.progressToken);
    if (turn instanceof Turn) {
      turn.error_message = data.error.message;
    }
  },
}
```

### Provider Status Check

Before sending, providers are checked:

```typescript
// In Thread.send_message()
const provider_status = this.app.lookup_provider_status(this.model.provider_name);
if (provider_status && !provider_status.available) {
  console.warn(`Provider '${this.model.provider_name}' unavailable`);
  return null;  // UI already shows error
}
```
