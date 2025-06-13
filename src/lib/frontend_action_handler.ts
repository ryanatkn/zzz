import type {Action_Input, Action_Output, Action_Phase} from '$lib/action_types.js';
import type {
	Frontend_Request_Response_Action_Event,
	Frontend_Remote_Notification_Action_Event,
	Frontend_Local_Call_Action_Event,
	Frontend_Action_Event,
} from '$lib/frontend_action_event.js';

/**
 * Frontend action handler type that receives an action event.
 * The handler can process the event data and return results for handling phases.
 *
 * @template T_Event The specific action event type
 * @template T_Phase The phase being handled
 * @template T_Output The output type (void for most phases, action output for handling phases)
 */
export type Frontend_Action_Handler<
	T_Event extends Frontend_Action_Event = Frontend_Action_Event,
	T_Phase extends Action_Phase = Action_Phase,
	T_Output = void,
> = (
	action_event: T_Event & {data: Extract<T_Event['data'], {phase: T_Phase; step: 'handling'}>},
) => T_Output | Promise<T_Output>;

/**
 * Type for request/response handlers on frontend.
 */
export type Frontend_Request_Response_Handler<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
	T_Phase extends Action_Phase = Action_Phase,
> = Frontend_Action_Handler<
	Frontend_Request_Response_Action_Event<any, T_Input, T_Output>,
	T_Phase,
	T_Phase extends 'receive_request' ? T_Output : void
>;

/**
 * Type for notification handlers on frontend.
 */
export type Frontend_Notification_Handler<
	T_Input extends Action_Input = Action_Input,
	T_Phase extends Action_Phase = Action_Phase,
> = Frontend_Action_Handler<Frontend_Remote_Notification_Action_Event<any, T_Input>, T_Phase, void>;

/**
 * Type for local call handlers on frontend.
 */
export type Frontend_Local_Call_Handler<
	T_Input extends Action_Input = Action_Input,
	T_Output extends Action_Output = Action_Output,
> = Frontend_Action_Handler<
	Frontend_Local_Call_Action_Event<any, T_Input, T_Output>,
	'execute',
	T_Output
>;
