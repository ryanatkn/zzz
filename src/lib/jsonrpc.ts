/**
 * Following MCP, Zzz supports a subset of JSON-RPC 2.0 as its message format
 * (A2A too, but I haven't looked into if they support the full spec).
 * It can be used by multiple transports including http and websocket.
 *
 * These are the JSON-RPC types from the MCP draft in May 2025,
 * changed to include a prefix on all identifiers.
 * It's also defined with Zod schemas instead of plain TS like the MCP library.
 *
 * MCP messages are a subset of JSON-RPC:
 *
 * - `params` does not support the positional array format,
 * 		and `result` supports only `object` values, instead of being any JSON value.
 * - MCP does not support batching,
 * 		see https://github.com/modelcontextprotocol/modelcontextprotocol/pull/416
 * 		and https://github.com/modelcontextprotocol/modelcontextprotocol/pull/228
 *
 * @source https://github.com/modelcontextprotocol/typescript-sdk
 * @see https://modelcontextprotocol.io/
 * @license https://github.com/modelcontextprotocol/typescript-sdk/blob/main/LICENSE
 *
 * MIT License
 *
 * Copyright (c) 2024 Anthropic, PBC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import {z} from 'zod';

export const JSONRPC_VERSION = '2.0';
export const JSONRPC_LATEST_PROTOCOL_VERSION = 'DRAFT-2025-v2';

/**
 * A uniquely identifying id for a request in JSON-RPC.
 *
 * Like MCP but unlike JSON-RPC, the type excludes null.
 */
export const Jsonrpc_Request_Id = z.union([z.string(), z.number()]);
export type Jsonrpc_Request_Id = z.infer<typeof Jsonrpc_Request_Id>;

/**
 * A JSON-RPC method name, a string with no constraints.
 */
export const Jsonrpc_Method = z.string();
export type Jsonrpc_Method = z.infer<typeof Jsonrpc_Method>;

/**
 * A progress token, used to associate progress notifications with the original request.
 */
export const Jsonrpc_Progress_Token = z.union([z.string(), z.number()]);
export type Jsonrpc_Progress_Token = z.infer<typeof Jsonrpc_Progress_Token>;

export const Jsonrpc_Mcp_Meta = z.looseObject({}); // uses looseObject to allow additional properties and support `.extend`
export type Jsonrpc_Mcp_Meta = z.infer<typeof Jsonrpc_Mcp_Meta>;

export const Jsonrpc_Request_Params_Meta = Jsonrpc_Mcp_Meta.extend({
	/**
	 * If specified, the caller is requesting out-of-band progress notifications
	 * for this request (as represented by notifications/progress).
	 * The value of this parameter is an opaque token that will be attached
	 * to any subsequent notifications.
	 * The receiver is not obligated to provide these notifications.
	 */
	progressToken: Jsonrpc_Progress_Token.optional(),
});
export type Jsonrpc_Request_Params_Meta = z.infer<typeof Jsonrpc_Request_Params_Meta>;

export const Jsonrpc_Request_Params = z.looseObject({
	_meta: Jsonrpc_Request_Params_Meta.optional(),
});
export type Jsonrpc_Request_Params = z.infer<typeof Jsonrpc_Request_Params>;

export const Jsonrpc_Notification_Params = z.looseObject({
	/**
	 * This parameter name is reserved by MCP to allow clients and servers
	 * to attach additional metadata to their responses and notifications.
	 */
	_meta: Jsonrpc_Mcp_Meta.optional(),
});
export type Jsonrpc_Notification_Params = z.infer<typeof Jsonrpc_Notification_Params>;

export const Jsonrpc_Params = z.union([Jsonrpc_Request_Params, Jsonrpc_Notification_Params]);
export type Jsonrpc_Params = z.infer<typeof Jsonrpc_Params>;

export const Jsonrpc_Result = z.looseObject({
	/**
	 * This result property is reserved by the protocol to allow clients and servers
	 * to attach additional metadata to their responses.
	 */
	_meta: Jsonrpc_Mcp_Meta.optional(),
});
export type Jsonrpc_Result = z.infer<typeof Jsonrpc_Result>;

/**
 * A request that expects a response.
 */
export const Jsonrpc_Request = z.looseObject({
	jsonrpc: z.literal(JSONRPC_VERSION),
	id: Jsonrpc_Request_Id,
	method: Jsonrpc_Method,
	params: Jsonrpc_Request_Params.optional(),
});
export type Jsonrpc_Request = z.infer<typeof Jsonrpc_Request>;

/**
 * A notification which does not expect a response.
 */
export const Jsonrpc_Notification = z.looseObject({
	jsonrpc: z.literal(JSONRPC_VERSION),
	method: Jsonrpc_Method,
	params: Jsonrpc_Notification_Params.optional(),
});
export type Jsonrpc_Notification = z.infer<typeof Jsonrpc_Notification>;

/**
 * A successful (non-error) response to a request.
 */
export const Jsonrpc_Response = z.looseObject({
	jsonrpc: z.literal(JSONRPC_VERSION),
	id: Jsonrpc_Request_Id,
	result: Jsonrpc_Result,
});
export type Jsonrpc_Response = z.infer<typeof Jsonrpc_Response>;

// TODO add Zzz-specific error codes with mapping
// Standard JSON-RPC error codes
export const JSONRPC_PARSE_ERROR = -32700;
export const JSONRPC_INVALID_REQUEST = -32600;
export const JSONRPC_METHOD_NOT_FOUND = -32601;
export const JSONRPC_INVALID_PARAMS = -32602;
export const JSONRPC_INTERNAL_ERROR = -32603;
export const JSONRPC_SERVER_ERROR_START = -32000;
export const JSONRPC_SERVER_ERROR_END = -32099;
// -32000 to -32099 - Server error - Reserved for implementation-defined server-errors.

export const Jsonrpc_Server_Error_Code = z
	.number()
	.gte(JSONRPC_SERVER_ERROR_END)
	.lte(JSONRPC_SERVER_ERROR_START)
	.brand('Jsonrpc_Server_Error_Code');
export type Jsonrpc_Server_Error_Code = z.infer<typeof Jsonrpc_Server_Error_Code>;

export const Jsonrpc_Error_Code = z.union([
	z.literal(JSONRPC_PARSE_ERROR),
	z.literal(JSONRPC_INVALID_REQUEST),
	z.literal(JSONRPC_METHOD_NOT_FOUND),
	z.literal(JSONRPC_INVALID_PARAMS),
	z.literal(JSONRPC_INTERNAL_ERROR),
	Jsonrpc_Server_Error_Code,
]);
export type Jsonrpc_Error_Code = z.infer<typeof Jsonrpc_Error_Code>;

export const Jsonrpc_Error_Json = z.looseObject({
	/**
	 * The error type that occurred.
	 */
	code: Jsonrpc_Error_Code,
	/**
	 * A short description of the error. The message SHOULD be limited to a concise single sentence.
	 */
	message: z.string(),
	/**
	 * Additional information about the error. The value of this member
	 * is defined by the sender (e.g. detailed error information, nested errors etc.).
	 */
	data: z.unknown().optional(),
});
export type Jsonrpc_Error_Json = z.infer<typeof Jsonrpc_Error_Json>;

/**
 * A response to a request that indicates an error occurred.
 */
export const Jsonrpc_Error_Message = z.looseObject({
	jsonrpc: z.literal(JSONRPC_VERSION),
	id: Jsonrpc_Request_Id.nullable(),
	error: Jsonrpc_Error_Json,
});
export type Jsonrpc_Error_Message = z.infer<typeof Jsonrpc_Error_Message>;

/**
 * Convenience helper union.
 */
export const Jsonrpc_Response_Or_Error = z.union([Jsonrpc_Response, Jsonrpc_Error_Message]);
export type Jsonrpc_Response_Or_Error = z.infer<typeof Jsonrpc_Response_Or_Error>;

/**
 * Refers to any valid JSON-RPC object that can be decoded off the wire, or encoded to be sent.
 */
export const Jsonrpc_Message = z.union([
	Jsonrpc_Request,
	Jsonrpc_Notification,
	Jsonrpc_Response,
	Jsonrpc_Error_Message,
	// Not supported by MCP, this shows what's omitted.
	// Jsonrpc_Batch_Request,
	// Jsonrpc_Batch_Response,
]);
export type Jsonrpc_Message = z.infer<typeof Jsonrpc_Message>;

export const Jsonrpc_Message_From_Client_To_Server = z.union([
	Jsonrpc_Request,
	Jsonrpc_Notification,
	// Not supported by MCP, this shows what's omitted.
	// Jsonrpc_Batch_Request,
]);
export type Jsonrpc_Message_From_Client_To_Server = z.infer<
	typeof Jsonrpc_Message_From_Client_To_Server
>;

export const Jsonrpc_Message_From_Server_To_Client = z.union([
	Jsonrpc_Notification,
	Jsonrpc_Response,
	Jsonrpc_Error_Message,
	// Not supported by MCP, this shows what's omitted.
	// Jsonrpc_Batch_Response,
]);
export type Jsonrpc_Message_From_Server_To_Client = z.infer<
	typeof Jsonrpc_Message_From_Server_To_Client
>;

export const Jsonrpc_Singular_Message = z.union([
	Jsonrpc_Request,
	Jsonrpc_Notification,
	Jsonrpc_Response,
	Jsonrpc_Error_Message,
]);
export type Jsonrpc_Singular_Message = z.infer<typeof Jsonrpc_Singular_Message>;

// Not supported by MCP, this shows what's omitted.
// export const Jsonrpc_Batch_Message = z.union([Jsonrpc_Batch_Request, Jsonrpc_Batch_Response]);
// export type Jsonrpc_Batch_Message = z.infer<typeof Jsonrpc_Batch_Message>;
// export const Jsonrpc_Batch_Request = z.array(z.union([Jsonrpc_Request, Jsonrpc_Notification]));
// export type Jsonrpc_Batch_Request = z.infer<typeof Jsonrpc_Batch_Request>;
// export const Jsonrpc_Batch_Response = z.array(Jsonrpc_Response_Or_Error);
// export type Jsonrpc_Batch_Response = z.infer<typeof Jsonrpc_Batch_Response>;
