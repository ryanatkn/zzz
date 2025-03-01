import {z} from 'zod';

import {Uuid} from '$lib/uuid.js';

export const Xml_Attribute = z.object({
	id: Uuid,
	key: z.string().default(''), // TODO BLOCK maybe Xml_Attribute_Key[_Base]
	value: z.string().default(''), // TODO BLOCK maybe Xml_Attribute_Value[_Base]
});
export type Xml_Attribute = z.infer<typeof Xml_Attribute>;
