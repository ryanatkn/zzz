import {z} from 'zod';

export const Uuid = z
	.string()
	.uuid()
	.brand('Uuid')
	.default(() => globalThis.crypto.randomUUID());
export type Uuid = z.infer<typeof Uuid>;
export type Uuid_Input = z.input<typeof Uuid>;
