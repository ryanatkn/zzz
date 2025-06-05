import type {Logger} from '@ryanatkn/belt/log.js';

import {
	type Jsonrpc_Response,
	type Jsonrpc_Error_Message,
	JSONRPC_PARSE_ERROR,
	JSONRPC_INVALID_REQUEST,
	Jsonrpc_Notification,
	Jsonrpc_Request,
	type Jsonrpc_Request_Id,
} from '$lib/jsonrpc.js';
import {
	create_jsonrpc_error_message,
	create_jsonrpc_error_message_from_thrown,
} from '$lib/jsonrpc_helpers.js';

/**
 * Handler for processing JSON-RPC requests
 */
export type Jsonrpc_Request_Handler = (
	request: Jsonrpc_Request,
) => Promise<Jsonrpc_Response | Jsonrpc_Error_Message>;

/**
 * Handler for processing JSON-RPC notifications
 */
export type Jsonrpc_Notification_Handler = (notification: Jsonrpc_Notification) => Promise<void>;

/**
 * Configuration options for the JSON-RPC server
 */
export interface Handle_Jsonrpc_Request_Options {
	message: any;

	/**
	 * Handler for processing JSON-RPC requests
	 */
	onrequest: Jsonrpc_Request_Handler;

	/**
	 * Handler for processing JSON-RPC notifications
	 */
	onnotification: Jsonrpc_Notification_Handler;

	/**
	 * Optional log instance
	 */
	log?: Logger | null;
}

// TODO need to support notifications and batch requests as well, but probably a different helper
/**
 * Process a JSON-RPC request and return a response.
 */
export const handle_jsonrpc_request = async (
	options: Handle_Jsonrpc_Request_Options,
): Promise<Jsonrpc_Response | Jsonrpc_Error_Message | null> => {
	const {message, onrequest, onnotification, log} = options;

	const id: Jsonrpc_Request_Id | undefined | null = message?.id; // include null for completeness

	try {
		// First attempt to validate as a request
		const parsed_request = Jsonrpc_Request.safeParse(message);
		if (parsed_request.success) {
			const request = parsed_request.data;
			try {
				return await onrequest(request);
			} catch (error) {
				log?.error(`Error processing JSON-RPC request:`, error);
				return create_jsonrpc_error_message_from_thrown(request.id, error);
			}
		}

		// If it's not a valid request, check if it's a notification
		const parsed_notification = Jsonrpc_Notification.safeParse(message);
		if (parsed_notification.success) {
			const notification = parsed_notification.data;
			try {
				await onnotification(notification);
			} catch (error) {
				log?.error(`Error processing JSON-RPC notification:`, error);
				// No response for notifications, so just log the error
			}
			return null; // No response for notifications
		}

		// If neither a valid request nor notification, it's an invalid request
		if (id == null) {
			// For notifications we can't return an error
			log?.error('JSON-RPC invalid request:', parsed_request.error);
			return null;
		}
		return create_jsonrpc_error_message(id, {
			code: JSONRPC_INVALID_REQUEST,
			message: 'invalid request',
		});
	} catch (error) {
		// If we can't even parse the JSON properly
		log?.error('JSON-RPC parse error:', error);
		if (id == null) {
			// For notifications we can't return an error
			return null;
		}
		return create_jsonrpc_error_message(id, {
			code: JSONRPC_PARSE_ERROR,
			message: 'parse error',
		});
	}
};
