import {z} from 'zod';

// TODO BLOCK @many would this ideally be merged with `*.svelte.ts`? this was designed because of a temporary server build problem. circular deps are weird though, maybe `*.schema.ts` instead?

export const Provider_Name = z.enum(['ollama', 'claude', 'chatgpt', 'gemini']);
export type Provider_Name = z.infer<typeof Provider_Name>;
