import {jsonrpc_errors, Jsonrpc_Error as Jsonrpc_Error_Exception} from '$lib/jsonrpc_errors.js';
import type {Action_Input, Action_Kind, Action_Output} from '$lib/action_types.js';
import {
	type Jsonrpc_Request,
	type Jsonrpc_Response,
	type Jsonrpc_Error_Message,
	type Jsonrpc_Notification,
	type Jsonrpc_Message_From_Server_To_Client,
	type Jsonrpc_Request_Id,
	type Jsonrpc_Batch_Response,
	JSONRPC_INTERNAL_ERROR,
	Jsonrpc_Result,
} from '$lib/jsonrpc.js';
import {
	create_jsonrpc_response,
	create_jsonrpc_error_message,
	is_jsonrpc_request,
	is_jsonrpc_notification,
	is_jsonrpc_batch_request,
} from '$lib/jsonrpc_helpers.js';
import {Action_Method} from '$lib/action_metatypes.js';
import {action_spec_by_method} from '$lib/action_collections.js';
import {stringify_zod_error} from '$lib/zod_helpers.js';
import type {Zzz_Server} from '$lib/server/zzz_server.js';
import type {Action_Spec} from '$lib/action_spec.js';

/**
 * Server event steps for processing incoming messages.
 */
export type Server_Event_Step = 'initial' | 'parsed' | 'handling' | 'handled' | 'error';

/**
 * Base event data structure for server events.
 */
export interface Server_Event_Data_Base {
	step: Server_Event_Step;
	method?: Action_Method;
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
	parse(): this {
		if (this.data.step !== 'initial') {
			throw new Error(`Cannot parse from step: ${this.data.step}`);
		}

		try {
			this.data = this.parse_data();
		} catch (error) {
			this.handle_parse_error(error);
		}

		return this;
	}

	/**
	 * Subclasses implement the actual parsing logic.
	 */
	protected abstract parse_data(): T_Event_Data;

	/**
	 * Subclasses implement error handling for parse failures.
	 */
	protected abstract handle_parse_error(error: unknown): void;

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
		if (is_jsonrpc_request(raw_message)) {
			return new Server_Request_Event(raw_message, server);
		} else if (is_jsonrpc_notification(raw_message)) {
			return new Server_Notification_Event(raw_message, server);
		} else if (is_jsonrpc_batch_request(raw_message)) {
			return new Server_Batch_Event(server, raw_message);
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

	/**
	 * Validate and parse a method string.
	 */
	protected validate_method(method: string): Action_Method {
		const parsed = Action_Method.safeParse(method);
		if (!parsed.success) {
			throw jsonrpc_errors.method_not_found(method);
		}
		return parsed.data;
	}

	/**
	 * Validate action spec exists and matches expected kind.
	 */
	protected validate_spec(method: Action_Method, expected_kind: Action_Kind): Action_Spec {
		const spec = action_spec_by_method.get(method);
		if (!spec) {
			throw jsonrpc_errors.method_not_found(method);
		}
		if (spec.kind !== expected_kind) {
			throw jsonrpc_errors.invalid_request(`method ${method} is not a ${expected_kind} action`);
		}
		return spec;
	}

	/**
	 * Validate and parse input parameters.
	 */
	protected validate_input<T>(method: Action_Method, params: unknown): T {
		const schema = this.server.lookup_action_input_schema(method);
		if (!schema) {
			throw jsonrpc_errors.internal_error(`unknown input schema: ${method}`);
		}

		const parsed = schema.safeParse(params);
		if (!parsed.success) {
			throw jsonrpc_errors.invalid_params(
				`invalid params to ${method}: ${stringify_zod_error(parsed.error)}`,
				{issues: parsed.error.issues},
			);
		}
		return parsed.data as T;
	}

	/**
	 * Validate and parse output result.
	 */
	protected validate_output<T>(method: Action_Method, output: unknown): T {
		const schema = this.server.lookup_action_output_schema(method);
		if (!schema) {
			throw jsonrpc_errors.internal_error(`unknown output schema: ${method}`);
		}

		const parsed = schema.safeParse(output);
		if (!parsed.success) {
			throw jsonrpc_errors.internal_error(
				`action response validation failed for ${method}: ${stringify_zod_error(parsed.error)}`,
				{issues: parsed.error.issues},
			);
		}
		return parsed.data as T;
	}
}

/**
 * Event data for incoming request messages.
 */
export type Server_Request_Event_Data<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> =
	| {
			step: 'initial';
			request: Jsonrpc_Request;
	  }
	| {
			step: 'parsed';
			method: Action_Method;
			input: T_Input;
			request: Jsonrpc_Request;
	  }
	| {
			step: 'handling';
			method: Action_Method;
			input: T_Input;
			request: Jsonrpc_Request;
	  }
	| {
			step: 'handled';
			method: Action_Method;
			input: T_Input;
			output: T_Output;
			request: Jsonrpc_Request;
			response: Jsonrpc_Response;
	  }
	| {
			step: 'error';
			error: Jsonrpc_Error_Message['error'];
			method?: Action_Method;
			input?: T_Input;
			request: Jsonrpc_Request;
			response: Jsonrpc_Error_Message;
	  };

/**
 * Event for handling incoming request messages.
 */
export class Server_Request_Event<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> extends Server_Action_Event<Server_Request_Event_Data<T_Input, T_Output>> {
	override readonly kind = 'request_response' as const;
	declare data: Server_Request_Event_Data<T_Input, T_Output>;

	constructor(request: Jsonrpc_Request, server: Zzz_Server) {
		super(server);
		this.data = {step: 'initial', request};
	}

	protected parse_data(): Server_Request_Event_Data<T_Input, T_Output> {
		const method = this.validate_method(this.data.request.method);
		this.validate_spec(method, 'request_response');
		const input = this.validate_input<T_Input>(method, this.data.request.params);

		return {
			step: 'parsed',
			method,
			input,
			request: this.data.request,
		};
	}

	protected handle_parse_error(error: unknown): void {
		const jsonrpc_error = this.to_jsonrpc_error(error);
		this.data = {
			step: 'error',
			error: jsonrpc_error,
			request: this.data.request,
			response: create_jsonrpc_error_message(this.data.request.id, jsonrpc_error),
		};
	}

	async handle(): Promise<this> {
		if (this.data.step !== 'parsed') {
			throw new Error(`Cannot handle from step: ${this.data.step}`);
		}

		// Transition to handling
		this.data = {
			step: 'handling',
			method: this.data.method,
			input: this.data.input,
			request: this.data.request,
		};

		try {
			// Look up handler
			const handler = this.server.lookup_action_handler(this.data.method, 'receive_request');

			if (!handler) {
				throw jsonrpc_errors.internal_error(`no handler for ${this.data.method}`);
			}

			// Execute handler
			const output = await handler(this);

			// Validate output
			const validated_output = this.validate_output<T_Output>(this.data.method, output);

			this.data = {
				step: 'handled',
				method: this.data.method,
				input: this.data.input,
				output: validated_output,
				request: this.data.request,
				response: create_jsonrpc_response(this.data.request.id, validated_output as Jsonrpc_Result), // TODO @api `Jsonrpc_Result.parse` upstream right?
			};
		} catch (error) {
			const jsonrpc_error = this.to_jsonrpc_error(error);
			this.data = {
				step: 'error',
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
		switch (this.data.step) {
			case 'handled':
			case 'error':
				return this.data.response;
			default:
				throw new Error(`Cannot build response from step: ${this.data.step}`);
		}
	}
}

/**
 * Event data for incoming notification messages.
 */
export type Server_Notification_Event_Data<T_Input extends Action_Input = Action_Input> =
	| {
			step: 'initial';
			notification: Jsonrpc_Notification;
	  }
	| {
			step: 'parsed';
			method: Action_Method;
			input: T_Input;
			notification: Jsonrpc_Notification;
	  }
	| {
			step: 'handling';
			method: Action_Method;
			input: T_Input;
			notification: Jsonrpc_Notification;
	  }
	| {
			step: 'handled';
			method: Action_Method;
			input: T_Input;
			notification: Jsonrpc_Notification;
	  }
	| {
			step: 'error';
			error: Jsonrpc_Error_Message['error'];
			method?: Action_Method;
			input?: T_Input;
			notification: Jsonrpc_Notification;
	  };

/**
 * Event for handling incoming notification messages.
 */
export class Server_Notification_Event<
	T_Input extends Action_Input = Action_Input,
> extends Server_Action_Event<Server_Notification_Event_Data<T_Input>> {
	override readonly kind = 'remote_notification' as const;
	declare data: Server_Notification_Event_Data<T_Input>;

	constructor(notification: Jsonrpc_Notification, server: Zzz_Server) {
		super(server);
		this.data = {step: 'initial', notification};
	}

	protected parse_data(): Server_Notification_Event_Data<T_Input> {
		const method = this.validate_method(this.data.notification.method);
		this.validate_spec(method, 'remote_notification');
		const input = this.validate_input<T_Input>(method, this.data.notification.params);

		return {
			step: 'parsed',
			method,
			input,
			notification: this.data.notification,
		};
	}

	protected handle_parse_error(error: unknown): void {
		const jsonrpc_error = this.to_jsonrpc_error(error);
		this.data = {
			step: 'error',
			error: jsonrpc_error,
			notification: this.data.notification,
		};
	}

	async handle(): Promise<this> {
		if (this.data.step !== 'parsed') {
			throw new Error(`Cannot handle from step: ${this.data.step}`);
		}

		// Transition to handling
		this.data = {
			step: 'handling',
			method: this.data.method,
			input: this.data.input,
			notification: this.data.notification,
		};

		try {
			// Look up handler
			const handler = this.server.lookup_action_handler(this.data.method, 'receive');

			if (!handler) {
				throw jsonrpc_errors.internal_error(`no handler for ${this.data.method}`);
			}

			// Execute handler
			await handler(this);

			this.data = {
				step: 'handled',
				method: this.data.method,
				input: this.data.input,
				notification: this.data.notification,
			};
		} catch (error) {
			const jsonrpc_error = this.to_jsonrpc_error(error);
			this.data = {
				step: 'error',
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
			step: 'initial';
	  }
	| {
			step: 'parsed';
			sub_events: Array<Server_Action_Event>;
	  }
	| {
			step: 'handling';
			sub_events: Array<Server_Action_Event>;
			current_index: number;
	  }
	| {
			step: 'handled';
			sub_events: Array<Server_Action_Event>;
	  }
	| {
			step: 'error';
			error: Jsonrpc_Error_Message['error'];
	  };

/**
 * Event for handling batch requests.
 */
export class Server_Batch_Event extends Server_Action_Event<Server_Batch_Event_Data> {
	override readonly kind = 'batch' as const;
	declare data: Server_Batch_Event_Data;

	raw_messages: Array<unknown>;

	constructor(server: Zzz_Server, raw_messages: Array<unknown>) {
		super(server);
		this.raw_messages = raw_messages;
		this.data = {step: 'initial'};
	}

	protected parse_data(): Server_Batch_Event_Data {
		// Empty batch is an error
		if (this.raw_messages.length === 0) {
			throw jsonrpc_errors.invalid_request('empty batch request');
		}

		// Create sub-events for each message
		const sub_events = this.raw_messages.map((m) => Server_Action_Event.from(this.server, m));

		// Parse all sub-events
		for (const event of sub_events) {
			event.parse();
		}

		return {step: 'parsed', sub_events};
	}

	protected handle_parse_error(error: unknown): void {
		const jsonrpc_error = this.to_jsonrpc_error(error);
		this.data = {step: 'error', error: jsonrpc_error};
	}

	async handle(): Promise<this> {
		if (this.data.step !== 'parsed') {
			throw new Error(`Cannot handle from step: ${this.data.step}`);
		}

		// Transition to handling
		this.data = {
			step: 'handling',
			sub_events: this.data.sub_events,
			current_index: 0,
		};

		// Process sub-events sequentially
		for (let i = 0; i < this.data.sub_events.length; i++) {
			this.data.current_index = i;

			await this.data.sub_events[i].handle(); // eslint-disable-line no-await-in-loop
		}

		this.data = {step: 'handled', sub_events: this.data.sub_events};
		return this;
	}

	build_response(): Jsonrpc_Batch_Response | null {
		if (this.data.step === 'error') {
			// Return single error response for batch-level errors
			return [create_jsonrpc_error_message('', this.data.error)];
		}

		if (this.data.step !== 'handled') {
			throw new Error(`Cannot build response from step: ${this.data.step}`);
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
			step: 'initial';
			raw_message: unknown;
	  }
	| {
			step: 'error';
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
		this.data = {step: 'initial', raw_message};
	}

	protected parse_data(): Server_Invalid_Event_Data {
		throw new Error(); // always error for invalid events
	}

	protected handle_parse_error(_error: unknown): void {
		this.data = {
			step: 'error',
			error: {
				code: jsonrpc_errors.invalid_request().code,
				message: 'Invalid request',
			},
			raw_message: this.data.raw_message,
		};
	}

	handle(): Promise<this> {
		// No-op for invalid events
		return Promise.resolve(this);
	}

	build_response(): Jsonrpc_Error_Message | null {
		if (this.data.step !== 'error') {
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
