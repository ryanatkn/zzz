import {z} from 'zod';

export const Provider_Name = z.enum(['ollama', 'claude', 'chatgpt', 'gemini']);
export type Provider_Name = z.infer<typeof Provider_Name>;
