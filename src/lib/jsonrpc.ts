/**
 * Following MCP and A2A, Zzz supports JSON-RPC 2.0 as its message format.
 * This can be used by multiple transports including http and websocket.
 *
 * These are the JSON-RPC types from the MCP draft in May 2025,
 * changed to include the `JSONRPC` prefix on all identifiers.
 * It's also defined with Zod schemas instead of MCP's plain TS.
 *
 * @source https://github.com/modelcontextprotocol/typescript-sdk
 * @see https://modelcontextprotocol.io/
 * @license https://github.com/modelcontextprotocol/typescript-sdk/blob/main/LICENSE
 */

import {z} from 'zod';

export const JSONRPC_VERSION = '2.0';
export const JSONRPC_LATEST_PROTOCOL_VERSION = 'DRAFT-2025-v2';

/**
 * A uniquely identifying ID for a request in JSON-RPC.
 *
 * Like MCP but unlike JSON-RPC, the type excludes null.
 */
export const JSONRPCRequestId = z.union([z.string(), z.number()]);
export type JSONRPCRequestId = z.infer<typeof JSONRPCRequestId>;

/**
 * A JSON-RPC method name, a string with no constraints.
 */
export const JSONRPCMethod = z.string();
export type JSONRPCMethod = z.infer<typeof JSONRPCMethod>;

/**
 * A progress token, used to associate progress notifications with the original request.
 */
export const JSONRPCProgressToken = z.union([z.string(), z.number()]);
export type JSONRPCProgressToken = z.infer<typeof JSONRPCProgressToken>;

export const JSONRPCMCPMeta = z.object({}).passthrough(); // uses object over record to be able to use the better `.extend`
export type JSONRPCMCPMeta = z.infer<typeof JSONRPCMCPMeta>;

export const JSONRPCRequestParamsMeta = JSONRPCMCPMeta.extend({
	/**
	 * If specified, the caller is requesting out-of-band progress notifications
	 * for this request (as represented by notifications/progress).
	 * The value of this parameter is an opaque token that will be attached
	 * to any subsequent notifications.
	 * The receiver is not obligated to provide these notifications.
	 */
	progressToken: JSONRPCProgressToken.optional(),
});
export type JSONRPCRequestParamsMeta = z.infer<typeof JSONRPCRequestParamsMeta>;

export const JSONRPCRequestParams = z
	.object({
		_meta: JSONRPCRequestParamsMeta.optional(),
	})
	.passthrough();
export type JSONRPCRequestParams = z.infer<typeof JSONRPCRequestParams>;

export const JSONRPCNotificationParams = z
	.object({
		/**
		 * This parameter name is reserved by MCP to allow clients and servers
		 * to attach additional metadata to their responses and notifications.
		 */
		_meta: JSONRPCMCPMeta.optional(),
	})
	.passthrough();
export type JSONRPCNotificationParams = z.infer<typeof JSONRPCNotificationParams>;

export const JSONRPCResult = z
	.object({
		/**
		 * This result property is reserved by the protocol to allow clients and servers
		 * to attach additional metadata to their responses.
		 */
		_meta: JSONRPCMCPMeta.optional(),
	})
	.passthrough();
export type JSONRPCResult = z.infer<typeof JSONRPCResult>;

/** Called `Request` in the MCP types. */
export const JSONRPCBaseRequest = z.object({
	method: z.string(),
	params: JSONRPCRequestParams.optional(),
});
export type JSONRPCBaseRequest = z.infer<typeof JSONRPCBaseRequest>;

/** Called `Notification` in the MCP types. */
export const JSONRPCBaseNotification = z.object({
	method: z.string(),
	params: JSONRPCNotificationParams.optional(),
});
export type JSONRPCBaseNotification = z.infer<typeof JSONRPCBaseNotification>;

/**
 * A request that expects a response.
 */
export const JSONRPCRequest = JSONRPCBaseRequest.extend({
	jsonrpc: z.literal(JSONRPC_VERSION),
	id: JSONRPCRequestId,
});
export type JSONRPCRequest = z.infer<typeof JSONRPCRequest>;

/**
 * A notification which does not expect a response.
 */
export const JSONRPCNotification = JSONRPCBaseNotification.extend({
	jsonrpc: z.literal(JSONRPC_VERSION),
});
export type JSONRPCNotification = z.infer<typeof JSONRPCNotification>;

/**
 * A successful (non-error) response to a request.
 */
export const JSONRPCResponse = z.object({
	jsonrpc: z.literal(JSONRPC_VERSION),
	id: JSONRPCRequestId,
	result: JSONRPCResult,
});
export type JSONRPCResponse = z.infer<typeof JSONRPCResponse>;

/**
 * A response to a request that indicates an error occurred.
 */
export const JSONRPCError = z.object({
	jsonrpc: z.literal(JSONRPC_VERSION),
	id: JSONRPCRequestId,
	error: z.object({
		/**
		 * The error type that occurred.
		 */
		code: z.number(),
		/**
		 * A short description of the error. The message SHOULD be limited to a concise single sentence.
		 */
		message: z.string(),
		/**
		 * Additional information about the error. The value of this member
		 * is defined by the sender (e.g. detailed error information, nested errors etc.).
		 */
		data: z.unknown().optional(),
	}),
});
export type JSONRPCError = z.infer<typeof JSONRPCError>;

// Standard JSON-RPC error codes
export const JSONRPC_PARSE_ERROR = -32700;
export const JSONRPC_INVALID_REQUEST = -32600;
export const JSONRPC_METHOD_NOT_FOUND = -32601;
export const JSONRPC_INVALID_PARAMS = -32602;
export const JSONRPC_INTERNAL_ERROR = -32603;
// -32000 to -32099 - Server error - Reserved for implementation-defined server-errors.

/**
 * A JSON-RPC batch request, as described in https://www.jsonrpc.org/specification#batch.
 */
export const JSONRPCBatchRequest = z.array(z.union([JSONRPCRequest, JSONRPCNotification]));
export type JSONRPCBatchRequest = z.infer<typeof JSONRPCBatchRequest>;

/**
 * A JSON-RPC batch response, as described in https://www.jsonrpc.org/specification#batch.
 */
export const JSONRPCBatchResponse = z.array(z.union([JSONRPCResponse, JSONRPCError]));
export type JSONRPCBatchResponse = z.infer<typeof JSONRPCBatchResponse>;

/**
 * Refers to any valid JSON-RPC object that can be decoded off the wire, or encoded to be sent.
 */
export const JSONRPCMessage = z.union([
	JSONRPCRequest,
	JSONRPCNotification,
	JSONRPCBatchRequest,
	JSONRPCResponse,
	JSONRPCError,
	JSONRPCBatchResponse,
]);
export type JSONRPCMessage = z.infer<typeof JSONRPCMessage>;
