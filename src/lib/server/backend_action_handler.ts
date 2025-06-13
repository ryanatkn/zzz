import type {Action_Input, Action_Output} from '$lib/action_types.js';
import type {
	Backend_Request_Event,
	Backend_Notification_Event,
	Backend_Request_Event_Data,
	Backend_Notification_Event_Data,
} from '$lib/server/backend_action_event.js';

/**
 * Type for a request event in the handling step.
 * This is what handlers actually receive - guaranteed to have method and input.
 */
export type Backend_Request_Event_Handling<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> = Backend_Request_Event<T_Input, T_Output> & {
	data: Extract<Backend_Request_Event_Data<T_Input, T_Output>, {step: 'handling'}>;
};

/**
 * Type for a notification event in the handling step.
 * This is what handlers actually receive - guaranteed to have method and input.
 */
export type Backend_Notification_Event_Handling<T_Input extends Action_Input = Action_Input> =
	Backend_Notification_Event<T_Input> & {
		data: Extract<Backend_Notification_Event_Data<T_Input>, {step: 'handling'}>;
	};

/**
 * Base server action handler for request/response actions with no authentication or authorization.
 * Receives a server event in the handling step and returns the output value.
 */
export type Public_Backend_Request_Handler<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> = (event: Backend_Request_Event_Handling<T_Input, T_Output>) => T_Output | Promise<T_Output>;

/**
 * Server action handler for request/response actions that require authorization.
 * Receives a server event in the handling step and returns the output value.
 */
export type Authorized_Backend_Request_Handler<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> = (event: Backend_Request_Event_Handling<T_Input, T_Output>) => T_Output | Promise<T_Output>;

/**
 * Base server action handler for notification actions with no authentication or authorization.
 * Receives a server event in the handling step and returns nothing.
 */
export type Public_Backend_Notification_Handler<T_Input extends Action_Input = Action_Input> = (
	event: Backend_Notification_Event_Handling<T_Input>,
) => void | Promise<void>;

/**
 * Server action handler for notification actions that require authorization.
 * Receives a server event in the handling step and returns nothing.
 */
export type Authorized_Backend_Notification_Handler<T_Input extends Action_Input = Action_Input> = (
	event: Backend_Notification_Event_Handling<T_Input>,
) => void | Promise<void>;

/**
 * Union type for all request/response handler types.
 */
export type Backend_Request_Handler<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> =
	| Public_Backend_Request_Handler<T_Input, T_Output>
	| Authorized_Backend_Request_Handler<T_Input, T_Output>;

/**
 * Union type for all notification handler types.
 */
export type Backend_Notification_Handler<T_Input extends Action_Input = Action_Input> =
	| Public_Backend_Notification_Handler<T_Input>
	| Authorized_Backend_Notification_Handler<T_Input>;

/**
 * Union type for all server action handlers.
 * Server action handlers receive events and return values or throw errors (see `Jsonrpc_Error`).
 */
export type Backend_Action_Handler<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> = Backend_Request_Handler<T_Input, T_Output> | Backend_Notification_Handler<T_Input>;
