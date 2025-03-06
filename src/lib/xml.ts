import {z} from 'zod';

import {Uuid, Uuid_Base} from '$lib/zod_helpers.js';

// Base schema enforces minimum length to reject empty strings
export const Xml_Attribute_Key_Base = z.string().min(1);
export type Xml_Attribute_Key_Base = z.infer<typeof Xml_Attribute_Key_Base>;

// Key with default maintains the min(1) constraint but uses a valid default
// Use attr_ prefix followed by a UUID-like substring as default (better than empty string)
export const Xml_Attribute_Key = Xml_Attribute_Key_Base.default(
	() => `attr_${crypto.randomUUID().substring(0, 8)}`,
);
export type Xml_Attribute_Key = z.infer<typeof Xml_Attribute_Key>;

export const Xml_Attribute_Value_Base = z.string();
export type Xml_Attribute_Value_Base = z.infer<typeof Xml_Attribute_Value_Base>;

export const Xml_Attribute_Value = Xml_Attribute_Value_Base.default('');
export type Xml_Attribute_Value = z.infer<typeof Xml_Attribute_Value>;

// Base attribute requires all fields with no defaults
export const Xml_Attribute_Base = z
	.object({
		id: Uuid_Base,
		key: Xml_Attribute_Key_Base,
		value: Xml_Attribute_Value_Base,
	})
	.strict();
export type Xml_Attribute_Base = z.infer<typeof Xml_Attribute_Base>;

// Default attribute applies defaults and includes id with default
export const Xml_Attribute = z
	.object({
		id: Uuid,
		key: Xml_Attribute_Key,
		value: Xml_Attribute_Value,
	})
	.strict();
export type Xml_Attribute = z.infer<typeof Xml_Attribute>;

// TODO: Consider adding support for XML namespaces and special XML character handling if needed// TODO?: Add element, document, and CDATA section schemas to create a complete XML model
