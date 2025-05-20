import type {
	JSONRPCMethod,
	JSONRPCNotification,
	JSONRPCNotificationParams,
	JSONRPCRequest,
	JSONRPCRequestId,
	JSONRPCRequestParams,
} from '$lib/jsonrpc.js';

export const create_jsonrpc_request = (
	method: JSONRPCMethod,
	params: JSONRPCRequestParams | void,
	id: JSONRPCRequestId,
): JSONRPCRequest => {
	const message: JSONRPCRequest = {
		jsonrpc: '2.0',
		id,
		method,
	};
	if (params !== undefined) {
		message.params = params;
	}

	return message;
};

// TODO currently unused, currently all actions are requests
export const create_jsonrpc_notification = (
	method: JSONRPCMethod,
	params: JSONRPCNotificationParams | void,
): JSONRPCNotification => {
	const message: JSONRPCNotification = {
		jsonrpc: '2.0',
		method,
	};
	if (params !== undefined) {
		message.params = params;
	}

	return message;
};
