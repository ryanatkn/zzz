import type {Action_Input, Action_Output} from '$lib/action_types.js';
import type {
	Server_Request_Event,
	Server_Notification_Event,
	Server_Request_Event_Data,
	Server_Notification_Event_Data,
} from '$lib/server/server_action_event.js';

/**
 * Type for a request event in the handling step.
 * This is what handlers actually receive - guaranteed to have method and input.
 */
export type Server_Request_Event_Handling<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> = Server_Request_Event<T_Input, T_Output> & {
	data: Extract<Server_Request_Event_Data<T_Input, T_Output>, {step: 'handling'}>;
};

/**
 * Type for a notification event in the handling step.
 * This is what handlers actually receive - guaranteed to have method and input.
 */
export type Server_Notification_Event_Handling<T_Input extends Action_Input = Action_Input> =
	Server_Notification_Event<T_Input> & {
		data: Extract<Server_Notification_Event_Data<T_Input>, {step: 'handling'}>;
	};

/**
 * Base server action handler for request/response actions with no authentication or authorization.
 * Receives a server event in the handling step and returns the output value.
 */
export type Public_Server_Request_Handler<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> = (event: Server_Request_Event_Handling<T_Input, T_Output>) => T_Output | Promise<T_Output>;

/**
 * Server action handler for request/response actions that require authorization.
 * Receives a server event in the handling step and returns the output value.
 */
export type Authorized_Server_Request_Handler<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> = (event: Server_Request_Event_Handling<T_Input, T_Output>) => T_Output | Promise<T_Output>;

/**
 * Base server action handler for notification actions with no authentication or authorization.
 * Receives a server event in the handling step and returns nothing.
 */
export type Public_Server_Notification_Handler<T_Input extends Action_Input = Action_Input> = (
	event: Server_Notification_Event_Handling<T_Input>,
) => void | Promise<void>;

/**
 * Server action handler for notification actions that require authorization.
 * Receives a server event in the handling step and returns nothing.
 */
export type Authorized_Server_Notification_Handler<T_Input extends Action_Input = Action_Input> = (
	event: Server_Notification_Event_Handling<T_Input>,
) => void | Promise<void>;

/**
 * Union type for all request/response handler types.
 */
export type Server_Request_Handler<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> =
	| Public_Server_Request_Handler<T_Input, T_Output>
	| Authorized_Server_Request_Handler<T_Input, T_Output>;

/**
 * Union type for all notification handler types.
 */
export type Server_Notification_Handler<T_Input extends Action_Input = Action_Input> =
	| Public_Server_Notification_Handler<T_Input>
	| Authorized_Server_Notification_Handler<T_Input>;

/**
 * Union type for all server action handlers.
 * Server action handlers receive events and return values or throw errors (see `Jsonrpc_Error`).
 */
export type Server_Action_Handler<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> = Server_Request_Handler<T_Input, T_Output> | Server_Notification_Handler<T_Input>;
