// bit.svelte.ts

import {z} from 'zod';

import {Uuid} from '$lib/uuid.js';

export const Xml_Attribute = z.object({
	id: Uuid,
	key: z.string().default(''),
	value: z.string().default(''),
});
export type Xml_Attribute = z.infer<typeof Xml_Attribute>;
