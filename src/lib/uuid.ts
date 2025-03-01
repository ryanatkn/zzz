import {z} from 'zod';

export const Uuid = z
	.string()
	.uuid()
	.brand('Uuid')
	.default(() => globalThis.crypto.randomUUID());
export type Uuid = z.infer<typeof Uuid>;
