import type {Action_Input, Action_Output} from '$lib/action_types.js';
import type {
	Server_Request_Event,
	Server_Notification_Event,
	Server_Request_Event_Data,
	Server_Notification_Event_Data,
} from '$lib/server/server_action_event.js';

/**
 * Type for a request event in the handling phase.
 * This is what handlers actually receive - guaranteed to have method and input.
 */
export type Server_Request_Event_Handling<
	T_Input = unknown,
	T_Output = unknown,
> = Server_Request_Event<T_Input, T_Output> & {
	data: Extract<Server_Request_Event_Data<T_Input, T_Output>, {phase: 'handling'}>;
};

/**
 * Type for a notification event in the handling phase.
 * This is what handlers actually receive - guaranteed to have method and input.
 */
export type Server_Notification_Event_Handling<T_Input = unknown> =
	Server_Notification_Event<T_Input> & {
		data: Extract<Server_Notification_Event_Data<T_Input>, {phase: 'handling'}>;
	};

/**
 * Base server action handler for request/response actions with no authentication or authorization.
 * Receives a server event in the handling phase and returns the output value.
 */
export type Public_Server_Request_Handler<
	T_Input extends Action_Input = any,
	T_Output extends Action_Output = any,
> = (event: Server_Request_Event_Handling<T_Input, T_Output>) => T_Output | Promise<T_Output>;

/**
 * Server action handler for request/response actions with full authorization (including authentication).
 * Receives a server event in the handling phase and returns the output value.
 */
export type Authorized_Server_Request_Handler<
	T_Input extends Action_Input = any,
	T_Output extends Action_Output = any,
> = (event: Server_Request_Event_Handling<T_Input, T_Output>) => T_Output | Promise<T_Output>;

/**
 * Base server action handler for notification actions with no authentication or authorization.
 * Receives a server event in the handling phase and returns nothing.
 */
export type Public_Server_Notification_Handler<T_Input extends Action_Input = any> = (
	event: Server_Notification_Event_Handling<T_Input>,
) => void | Promise<void>;

/**
 * Server action handler for notification actions with full authorization (including authentication).
 * Receives a server event in the handling phase and returns nothing.
 */
export type Authorized_Server_Notification_Handler<T_Input extends Action_Input = any> = (
	event: Server_Notification_Event_Handling<T_Input>,
) => void | Promise<void>;

/**
 * Union type for all request/response handler types.
 */
export type Server_Request_Handler<
	T_Input extends Action_Input = any,
	T_Output extends Action_Output = any,
> =
	| Public_Server_Request_Handler<T_Input, T_Output>
	| Authorized_Server_Request_Handler<T_Input, T_Output>;

/**
 * Union type for all notification handler types.
 */
export type Server_Notification_Handler<T_Input extends Action_Input = any> =
	| Public_Server_Notification_Handler<T_Input>
	| Authorized_Server_Notification_Handler<T_Input>;

/**
 * Union type for all server action handlers.
 * Server action handlers receive events and return values or throw errors (see `Jsonrpc_Error`).
 */
export type Server_Action_Handler<
	T_Input extends Action_Input = any,
	T_Output extends Action_Output = any,
> = Server_Request_Handler<T_Input, T_Output> | Server_Notification_Handler<T_Input>;
