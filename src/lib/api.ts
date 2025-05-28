import {z} from 'zod';

export const Http_Method = z.enum([
	'CONNECT',
	'DELETE',
	'GET',
	'HEAD',
	'OPTIONS',
	'PATCH',
	'POST',
	'PUT',
	'TRACE',
]);
export type Http_Method = z.infer<typeof Http_Method>;
