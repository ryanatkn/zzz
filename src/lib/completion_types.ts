import {z} from 'zod';

import {Datetime_Now} from '$lib/zod_helpers.js';
import {Provider_Name, Provider_Data_Schema} from '$lib/provider_types.js';

// TODO any restrictions?
export const Completion_Role = z.string(); // branding is too unwieldy at data declaration sites
export type Completion_Role = z.infer<typeof Completion_Role>;

export const Completion_Message = z.looseObject({
	role: Completion_Role,
	content: z.string(), // TODO maybe rename to `text` or something, see the APIs, they have different names
});
export type Completion_Message = z.infer<typeof Completion_Message>;

export const Completion_Request = z.strictObject({
	created: Datetime_Now,
	provider_name: Provider_Name,
	model: z.string(),
	prompt: z.string(),
	// TODO rename? this API is going to change likely to fit better with the responses API
	completion_messages: z.array(Completion_Message).optional(),
});
export type Completion_Request = z.infer<typeof Completion_Request>;

export const Completion_Response = z.strictObject({
	created: Datetime_Now,
	provider_name: Provider_Name,
	model: z.string(),
	data: Provider_Data_Schema,
});
export type Completion_Response = z.infer<typeof Completion_Response>;
