import {z} from 'zod';

import {Datetime_Now} from '$lib/zod_helpers.js';
import {Provider_Name, Provider_Data_Schema} from '$lib/provider_types.js';

// TODO needs to be open ended right? any benefit to an enum system/user/assistant? maybe merge with `Strip_Role`
export const Completion_Role = z.string(); // branding is too unwieldy at data declaration sites
export type Completion_Role = z.infer<typeof Completion_Role>;

export const Completion_Message = z.object({
	role: Completion_Role,
	content: z.string(),
});
export type Completion_Message = z.infer<typeof Completion_Message>;

export const Completion_Request = z
	.object({
		created: Datetime_Now,
		provider_name: Provider_Name,
		model: z.string(),
		prompt: z.string(),
		completion_messages: z.array(Completion_Message).optional(),
	})
	.strict();
export type Completion_Request = z.infer<typeof Completion_Request>;

export const Completion_Response = z
	.object({
		created: Datetime_Now,
		provider_name: Provider_Name,
		model: z.string(),
		data: Provider_Data_Schema,
	})
	.strict();
export type Completion_Response = z.infer<typeof Completion_Response>;
