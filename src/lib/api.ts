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

/**
 * Flag to indicate the phase of a request/response action.
 * - 'request': The action is being sent to the server
 * - 'response': The server has responded to the action
 * - null: The action is not a request/response type (e.g., client_local, server_notification)
 */
export type Api_Request_Response_Flag = 'request' | 'response' | null;
