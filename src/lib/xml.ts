import {z} from 'zod';

import {Uuid, Uuid_With_Default} from '$lib/zod_helpers.js';

export const Xml_Attribute_Key = z
	.string()
	.transform((s) => s.trim())
	.pipe(z.string().min(1));
export type Xml_Attribute_Key = z.infer<typeof Xml_Attribute_Key>;

export const Xml_Attribute_Key_With_Default = Xml_Attribute_Key.default('attr');
export type Xml_Attribute_Key_With_Default = z.infer<typeof Xml_Attribute_Key_With_Default>;

export const Xml_Attribute_Value = z.string();
export type Xml_Attribute_Value = z.infer<typeof Xml_Attribute_Value>;

export const Xml_Attribute_Value_With_Default = Xml_Attribute_Value.default('');
export type Xml_Attribute_Value_With_Default = z.infer<typeof Xml_Attribute_Value_With_Default>;

// TODO is strict desired?
// Base attribute requires all fields with no defaults
export const Xml_Attribute = z.strictObject({
	id: Uuid,
	key: Xml_Attribute_Key,
	value: Xml_Attribute_Value,
});
export type Xml_Attribute = z.infer<typeof Xml_Attribute>;

// TODO is strict desired?
// Default attribute applies defaults and includes id with default
export const Xml_Attribute_With_Defaults = z.strictObject({
	id: Uuid_With_Default,
	key: Xml_Attribute_Key_With_Default,
	value: Xml_Attribute_Value_With_Default,
});
export type Xml_Attribute_With_Defaults = z.infer<typeof Xml_Attribute_With_Defaults>;

// TODO Consider adding support for XML namespaces and special XML character handling if needed// TODO?: Add element, document, and CDATA section schemas to create a complete XML model
