import {jsonrpc_errors, Jsonrpc_Error as Jsonrpc_Error_Exception} from '$lib/jsonrpc_errors.js';
import type {Action_Kind} from '$lib/action_types.js';
import {
	type Jsonrpc_Request,
	type Jsonrpc_Response,
	type Jsonrpc_Error_Message,
	type Jsonrpc_Notification,
	type Jsonrpc_Message_From_Server_To_Client,
	type Jsonrpc_Request_Id,
	type Jsonrpc_Batch_Response,
	JSONRPC_INTERNAL_ERROR,
} from '$lib/jsonrpc.js';
import {create_jsonrpc_response, create_jsonrpc_error_message} from '$lib/jsonrpc_helpers.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {Action_Inputs, Action_Outputs, action_spec_by_method} from '$lib/action_collections.js';
import {stringify_zod_error} from '$lib/zod_helpers.js';
import type {Zzz_Server} from '$lib/server/zzz_server.js';

/**
 * Server event phases for processing incoming messages.
 */
export type Server_Event_Phase = 'initial' | 'parsed' | 'handling' | 'handled' | 'error';

/**
 * Base event data structure for server events.
 */
export interface Server_Event_Data_Base {
	phase: Server_Event_Phase;
	method?: string;
	input?: unknown;
	output?: unknown;
	error?: unknown;
}

/**
 * Abstract base class for server action events.
 * Handles incoming JSON-RPC messages from clients.
 */
export abstract class Server_Action_Event<
	T_Event_Data extends Server_Event_Data_Base = Server_Event_Data_Base,
> {
	abstract readonly kind: Action_Kind | 'batch';
	abstract data: T_Event_Data;

	/**
	 * The server context processing this event.
	 */
	readonly server: Zzz_Server;

	/**
	 * Error creation helper with same interface as jsonrpc_errors.
	 * Handlers can throw using: throw event.errors.method_not_found(...)
	 */
	readonly errors = jsonrpc_errors;

	constructor(server: Zzz_Server) {
		this.server = server;
	}

	/**
	 * Parse and validate the incoming message.
	 * Should transition from initial state to parsed or error.
	 */
	abstract parse(): this;

	/**
	 * Execute the handler for this event.
	 * Should transition from parsed state to handling to handled or error.
	 */
	abstract handle(): Promise<this>;

	/**
	 * Build the appropriate response to send back to the client.
	 */
	abstract build_response(): Jsonrpc_Message_From_Server_To_Client | null;

	/**
	 * Static factory to create the appropriate event type from a raw message.
	 * Only handles requests, notifications, and batches - never responses or errors.
	 */
	static from(server: Zzz_Server, raw_message: unknown): Server_Action_Event {
		// First check if it's a batch (array)
		if (Array.isArray(raw_message)) {
			return new Server_Batch_Event(server, raw_message);
		}

		// Check if it's a valid JSON-RPC message at all
		if (!raw_message || typeof raw_message !== 'object') {
			return new Server_Invalid_Event(server, raw_message);
		}

		// Server only receives requests and notifications
		if ('method' in raw_message) {
			if ('id' in raw_message) {
				return new Server_Request_Event(raw_message as Jsonrpc_Request, server);
			} else {
				return new Server_Notification_Event(raw_message as Jsonrpc_Notification, server);
			}
		}

		// Not a valid message type
		return new Server_Invalid_Event(server, raw_message);
	}

	/**
	 * Convert any error to a JSON-RPC error.
	 */
	protected to_jsonrpc_error(error: unknown): Jsonrpc_Error_Message['error'] {
		if (error instanceof Jsonrpc_Error_Exception) {
			return {
				code: error.code,
				message: error.message,
				data: error.data,
			};
		}

		if (error instanceof Error) {
			return {
				code: JSONRPC_INTERNAL_ERROR,
				message: error.message,
			};
		}

		return {
			code: JSONRPC_INTERNAL_ERROR,
			message: 'Unknown error',
		};
	}
}

/**
 * Event data for incoming request messages.
 */
export type Server_Request_Event_Data<T_Input = unknown, T_Output = unknown> =
	| {
			phase: 'initial';
			request: Jsonrpc_Request;
	  }
	| {
			phase: 'parsed';
			method: string;
			input: T_Input;
			request: Jsonrpc_Request;
	  }
	| {
			phase: 'handling';
			method: string;
			input: T_Input;
			request: Jsonrpc_Request;
	  }
	| {
			phase: 'handled';
			method: string;
			input: T_Input;
			output: T_Output;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response;
	  }
	| {
			phase: 'error';
			error: Jsonrpc_Error_Message['error'];
			method?: string;
			input?: T_Input;
			request: Jsonrpc_Request;
			response: Jsonrpc_Error_Message;
	  };

/**
 * Event for handling incoming request messages.
 */
export class Server_Request_Event<
	T_Input = unknown,
	T_Output = unknown,
> extends Server_Action_Event<Server_Request_Event_Data<T_Input, T_Output>> {
	override readonly kind = 'request_response' as const;
	declare data: Server_Request_Event_Data<T_Input, T_Output>;

	constructor(request: Jsonrpc_Request, server: Zzz_Server) {
		super(server);
		this.data = {phase: 'initial', request};
	}

	parse(): this {
		if (this.data.phase !== 'initial') {
			throw new Error(`Cannot parse from phase: ${this.data.phase}`);
		}

		try {
			// Validate method
			const parsed_method = Action_Method.safeParse(this.data.request.method);
			if (!parsed_method.success) {
				throw jsonrpc_errors.method_not_found(this.data.request.method);
			}
			const method = parsed_method.data;

			// Get action spec
			const spec = action_spec_by_method.get(method);
			if (!spec) {
				throw jsonrpc_errors.method_not_found(method);
			}

			// Validate this is a request/response action
			if (spec.kind !== 'request_response') {
				throw jsonrpc_errors.invalid_request(`method ${method} is not a request/response action`);
			}

			// Validate input
			const input_schema = Action_Inputs[method];
			if (!input_schema) {
				throw jsonrpc_errors.internal_error(`unknown input schema: ${method}`);
			}

			const parsed_input = input_schema.safeParse(this.data.request.params);
			if (!parsed_input.success) {
				throw jsonrpc_errors.invalid_params(
					`invalid params to ${method}: ${stringify_zod_error(parsed_input.error)}`,
					{issues: parsed_input.error.issues},
				);
			}

			this.data = {
				phase: 'parsed',
				method,
				input: parsed_input.data as T_Input,
				request: this.data.request,
			};
		} catch (error) {
			const jsonrpc_error = this.to_jsonrpc_error(error);
			this.data = {
				phase: 'error',
				error: jsonrpc_error,
				request: this.data.request,
				response: create_jsonrpc_error_message(this.data.request.id, jsonrpc_error),
			};
		}

		return this;
	}

	async handle(): Promise<this> {
		if (this.data.phase !== 'parsed') {
			throw new Error(`Cannot handle from phase: ${this.data.phase}`);
		}

		// Transition to handling
		this.data = {
			phase: 'handling',
			method: this.data.method,
			input: this.data.input,
			request: this.data.request,
		};

		try {
			// Look up handler
			const handler = this.server.lookup_handler(this.data.method, 'receive_request');

			if (!handler) {
				throw jsonrpc_errors.internal_error(`no handler for ${this.data.method}`);
			}

			// Execute handler
			const output = await handler(this);

			// Validate output
			const output_schema = Action_Outputs[this.data.method];
			if (!output_schema) {
				throw jsonrpc_errors.internal_error(`unknown output schema: ${this.data.method}`);
			}

			const parsed_output = output_schema.safeParse(output);
			if (!parsed_output.success) {
				throw jsonrpc_errors.internal_error(
					`action response validation failed for ${this.data.method}: ${stringify_zod_error(parsed_output.error)}`,
					{issues: parsed_output.error.issues},
				);
			}

			this.data = {
				phase: 'handled',
				method: this.data.method,
				input: this.data.input,
				output: parsed_output.data as T_Output,
				request: this.data.request,
				response: create_jsonrpc_response(this.data.request.id, parsed_output.data),
			};
		} catch (error) {
			const jsonrpc_error = this.to_jsonrpc_error(error);
			this.data = {
				phase: 'error',
				error: jsonrpc_error,
				method: this.data.method,
				input: this.data.input,
				request: this.data.request,
				response: create_jsonrpc_error_message(this.data.request.id, jsonrpc_error),
			};
		}

		return this;
	}

	build_response(): Jsonrpc_Response | Jsonrpc_Error_Message {
		switch (this.data.phase) {
			case 'handled':
			case 'error':
				return this.data.response;
			default:
				throw new Error(`Cannot build response from phase: ${this.data.phase}`);
		}
	}
}

/**
 * Event data for incoming notification messages.
 */
export type Server_Notification_Event_Data<T_Input = unknown> =
	| {
			phase: 'initial';
			notification: Jsonrpc_Notification;
	  }
	| {
			phase: 'parsed';
			method: string;
			input: T_Input;
			notification: Jsonrpc_Notification;
	  }
	| {
			phase: 'handling';
			method: string;
			input: T_Input;
			notification: Jsonrpc_Notification;
	  }
	| {
			phase: 'handled';
			method: string;
			input: T_Input;
			notification: Jsonrpc_Notification;
	  }
	| {
			phase: 'error';
			error: Jsonrpc_Error_Message['error'];
			method?: string;
			input?: T_Input;
			notification: Jsonrpc_Notification;
	  };

/**
 * Event for handling incoming notification messages.
 */
export class Server_Notification_Event<T_Input = unknown> extends Server_Action_Event<
	Server_Notification_Event_Data<T_Input>
> {
	override readonly kind = 'remote_notification' as const;
	declare data: Server_Notification_Event_Data<T_Input>;

	constructor(notification: Jsonrpc_Notification, server: Zzz_Server) {
		super(server);
		this.data = {phase: 'initial', notification};
	}

	parse(): this {
		if (this.data.phase !== 'initial') {
			throw new Error(`Cannot parse from phase: ${this.data.phase}`);
		}

		try {
			// Validate method
			const parsed_method = Action_Method.safeParse(this.data.notification.method);
			if (!parsed_method.success) {
				throw jsonrpc_errors.method_not_found(this.data.notification.method);
			}
			const method = parsed_method.data;

			// Get action spec
			const spec = action_spec_by_method.get(method);
			if (!spec) {
				throw jsonrpc_errors.method_not_found(method);
			}

			// Validate this is a notification action
			if (spec.kind !== 'remote_notification') {
				throw jsonrpc_errors.invalid_request(`method ${method} is not a notification action`);
			}

			// Validate input
			const input_schema = Action_Inputs[method];
			if (!input_schema) {
				throw jsonrpc_errors.internal_error(`unknown input schema: ${method}`);
			}

			const parsed_input = input_schema.safeParse(this.data.notification.params);
			if (!parsed_input.success) {
				throw jsonrpc_errors.invalid_params(
					`invalid params to ${method}: ${stringify_zod_error(parsed_input.error)}`,
					{issues: parsed_input.error.issues},
				);
			}

			this.data = {
				phase: 'parsed',
				method,
				input: parsed_input.data as T_Input,
				notification: this.data.notification,
			};
		} catch (error) {
			const jsonrpc_error = this.to_jsonrpc_error(error);
			this.data = {
				phase: 'error',
				error: jsonrpc_error,
				notification: this.data.notification,
			};
		}

		return this;
	}

	async handle(): Promise<this> {
		if (this.data.phase !== 'parsed') {
			throw new Error(`Cannot handle from phase: ${this.data.phase}`);
		}

		// Transition to handling
		this.data = {
			phase: 'handling',
			method: this.data.method,
			input: this.data.input,
			notification: this.data.notification,
		};

		try {
			// Look up handler
			const handler = this.server.lookup_handler(this.data.method, 'receive');

			if (!handler) {
				throw jsonrpc_errors.internal_error(`no handler for ${this.data.method}`);
			}

			// Execute handler
			await handler(this);

			this.data = {
				phase: 'handled',
				method: this.data.method,
				input: this.data.input,
				notification: this.data.notification,
			};
		} catch (error) {
			const jsonrpc_error = this.to_jsonrpc_error(error);
			this.data = {
				phase: 'error',
				error: jsonrpc_error,
				method: this.data.method,
				input: this.data.input,
				notification: this.data.notification,
			};
		}

		return this;
	}

	build_response(): null {
		// Notifications never return responses
		return null;
	}
}

/**
 * Event data for batch requests.
 */
export type Server_Batch_Event_Data =
	| {
			phase: 'initial';
			raw_messages: Array<unknown>;
	  }
	| {
			phase: 'parsed';
			sub_events: Array<Server_Action_Event>;
	  }
	| {
			phase: 'handling';
			sub_events: Array<Server_Action_Event>;
			current_index: number;
	  }
	| {
			phase: 'handled';
			sub_events: Array<Server_Action_Event>;
	  }
	| {
			phase: 'error';
			error: Jsonrpc_Error_Message['error'];
	  };

/**
 * Event for handling batch requests.
 */
export class Server_Batch_Event extends Server_Action_Event<Server_Batch_Event_Data> {
	override readonly kind = 'batch' as const;
	declare data: Server_Batch_Event_Data;

	constructor(server: Zzz_Server, raw_messages: Array<unknown>) {
		super(server);
		this.data = {phase: 'initial', raw_messages};
	}

	parse(): this {
		if (this.data.phase !== 'initial') {
			throw new Error(`Cannot parse from phase: ${this.data.phase}`);
		}

		try {
			// Empty batch is an error
			if (this.data.raw_messages.length === 0) {
				throw jsonrpc_errors.invalid_request('empty batch request');
			}

			// Create sub-events for each message
			const sub_events = this.data.raw_messages.map((msg) =>
				Server_Action_Event.from(this.server, msg),
			);

			// Parse all sub-events
			for (const event of sub_events) {
				event.parse();
			}

			this.data = {phase: 'parsed', sub_events};
		} catch (error) {
			const jsonrpc_error = this.to_jsonrpc_error(error);
			this.data = {phase: 'error', error: jsonrpc_error};
		}

		return this;
	}

	async handle(): Promise<this> {
		if (this.data.phase !== 'parsed') {
			throw new Error(`Cannot handle from phase: ${this.data.phase}`);
		}

		// Transition to handling
		this.data = {
			phase: 'handling',
			sub_events: this.data.sub_events,
			current_index: 0,
		};

		// Process sub-events sequentially
		for (let i = 0; i < this.data.sub_events.length; i++) {
			this.data.current_index = i;

			await this.data.sub_events[i].handle(); // eslint-disable-line no-await-in-loop
		}

		this.data = {phase: 'handled', sub_events: this.data.sub_events};
		return this;
	}

	build_response(): Jsonrpc_Batch_Response | null {
		if (this.data.phase === 'error') {
			// Return single error response for batch-level errors
			return [create_jsonrpc_error_message('', this.data.error)];
		}

		if (this.data.phase !== 'handled') {
			throw new Error(`Cannot build response from phase: ${this.data.phase}`);
		}

		// Build responses maintaining 1:1 correspondence with input
		// Filter out null responses (from notifications) for the final result
		const responses: Array<Jsonrpc_Response | Jsonrpc_Error_Message> = [];

		for (const event of this.data.sub_events) {
			const response = event.build_response();
			// Only add non-null responses (notifications return null)
			if (response !== null) {
				responses.push(response as Jsonrpc_Response | Jsonrpc_Error_Message);
			}
		}

		// If all were notifications, return null per JSON-RPC spec
		return responses.length > 0 ? responses : null;
	}
}

/**
 * Event data for invalid messages.
 */
export type Server_Invalid_Event_Data =
	| {
			phase: 'initial';
			raw_message: unknown;
	  }
	| {
			phase: 'error';
			error: Jsonrpc_Error_Message['error'];
			raw_message: unknown;
	  };

/**
 * Event for messages that fail initial validation.
 */
export class Server_Invalid_Event extends Server_Action_Event<Server_Invalid_Event_Data> {
	override readonly kind = 'request_response' as const; // Assume request to try returning error
	declare data: Server_Invalid_Event_Data;

	constructor(server: Zzz_Server, raw_message: unknown) {
		super(server);
		this.data = {phase: 'initial', raw_message};
	}

	parse(): this {
		// Always transitions to error
		this.data = {
			phase: 'error',
			error: {
				code: jsonrpc_errors.invalid_request().code,
				message: 'Invalid request',
			},
			raw_message: this.data.raw_message,
		};
		return this;
	}

	handle(): Promise<this> {
		// No-op for invalid events
		return Promise.resolve(this); // TODO cleaner?
	}

	build_response(): Jsonrpc_Error_Message | null {
		if (this.data.phase !== 'error') {
			return null;
		}

		// Try to extract an ID from the raw message
		const id = this.maybe_extract_id();
		if (id == null) {
			return null; // Can't return error without ID
		}

		return create_jsonrpc_error_message(id, this.data.error);
	}

	private maybe_extract_id(): Jsonrpc_Request_Id | null {
		try {
			const raw = this.data.raw_message;

			if (raw && typeof raw === 'object' && 'id' in raw) {
				const id = (raw as any).id;
				if (typeof id === 'string' || typeof id === 'number') {
					return id;
				}
			}
		} catch {
			// Ignore errors in ID extraction
		}
		return null;
	}
}
