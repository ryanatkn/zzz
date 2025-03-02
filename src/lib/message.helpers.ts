/**
 * Helper functions for working with messages
 */
import type {Message} from '$lib/message.schema.js';

/**
 * Checks if a message is of a certain type
 */
export function is_message_type<T extends Message>(
	message: Message,
	type: T['type'],
): message is T {
	return message.type === type;
}

/**
 * Extract only the relevant properties from messages for debugging
 */
export function get_message_debug_info(message: Message): object {
	return {
		id: message.id,
		type: message.type,
		// Add any other relevant fields for debugging
	};
}
