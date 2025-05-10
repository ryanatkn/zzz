/**
 * JSON-RPC types from MCP, with some modifications.
 *
 * @source https://github.com/modelcontextprotocol/typescript-sdk
 * @see https://modelcontextprotocol.io/
 * @license https://github.com/modelcontextprotocol/typescript-sdk/blob/main/LICENSE
 */

/**
 * Refers to any valid JSON-RPC object that can be decoded off the wire, or encoded to be sent.
 */
export type JSONRPCMessage =
	| JSONRPCRequest
	| JSONRPCNotification
	| JSONRPCBatchRequest
	| JSONRPCResponse
	| JSONRPCError
	| JSONRPCBatchResponse;

/**
 * A JSON-RPC batch request, as described in https://www.jsonrpc.org/specification#batch.
 */
export type JSONRPCBatchRequest = Array<JSONRPCRequest | JSONRPCNotification>;

/**
 * A JSON-RPC batch response, as described in https://www.jsonrpc.org/specification#batch.
 */
export type JSONRPCBatchResponse = Array<JSONRPCResponse | JSONRPCError>;

export const JSONRPC_VERSION = '2.0';
export const JSONRPC_LATEST_PROTOCOL_VERSION = 'DRAFT-2025-v2';

/**
 * A progress token, used to associate progress notifications with the original request.
 */
export type JSONRPCProgressToken = string | number;

export interface JSONRPCBaseRequest {
	method: string;
	params?: {
		_meta?: {
			/**
			 * If specified, the caller is requesting out-of-band progress notifications
			 * for this request (as represented by notifications/progress).
			 * The value of this parameter is an opaque token that will be attached
			 * to any subsequent notifications.
			 * The receiver is not obligated to provide these notifications.
			 */
			progressToken?: JSONRPCProgressToken;
		};
		[key: string]: unknown;
	};
}

export interface JSONRPCBaseNotification {
	method: string;
	params?: {
		/**
		 * This parameter name is reserved by MCP to allow clients and servers
		 * to attach additional metadata to their notifications.
		 */
		_meta?: Record<string, unknown>;
		[key: string]: unknown;
	};
}

export interface JSONRPCResult {
	/**
	 * This result property is reserved by the protocol to allow clients and servers
	 * to attach additional metadata to their responses.
	 */
	_meta?: Record<string, unknown>;
	[key: string]: unknown;
}

/**
 * A uniquely identifying ID for a request in JSON-RPC.
 */
export type RequestId = string | number;

/**
 * A request that expects a response.
 */
export interface JSONRPCRequest extends JSONRPCBaseRequest {
	jsonrpc: typeof JSONRPC_VERSION;
	id: RequestId;
}

/**
 * A notification which does not expect a response.
 */
export interface JSONRPCNotification extends JSONRPCBaseNotification {
	jsonrpc: typeof JSONRPC_VERSION;
}

/**
 * A successful (non-error) response to a request.
 */
export interface JSONRPCResponse {
	jsonrpc: typeof JSONRPC_VERSION;
	id: RequestId;
	result: JSONRPCResult;
}

// Standard JSON-RPC error codes
export const JSONRPC_PARSE_ERROR = -32700;
export const JSONRPC_INVALID_REQUEST = -32600;
export const JSONRPC_METHOD_NOT_FOUND = -32601;
export const JSONRPC_INVALID_PARAMS = -32602;
export const JSONRPC_INTERNAL_ERROR = -32603;

/**
 * A response to a request that indicates an error occurred.
 */
export interface JSONRPCError {
	jsonrpc: typeof JSONRPC_VERSION;
	id: RequestId;
	error: {
		/**
		 * The error type that occurred.
		 */
		code: number;
		/**
		 * A short description of the error. The message SHOULD be limited to a concise single sentence.
		 */
		message: string;
		/**
		 * Additional information about the error. The value of this member
		 * is defined by the sender (e.g. detailed error information, nested errors etc.).
		 */
		data?: unknown;
	};
}
