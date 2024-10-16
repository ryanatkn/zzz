import type {Receive_Prompt_Message, Send_Prompt_Message} from './zzz_message.js';

// Common wrapper around a conversation with a group agent.
// Groups history across multiple agents and prompts.
// Other single-word names: Log, History, Session, Logbook, Dialogue, Conversation, Chat, Transcript
// Other names using `Prompt_`: Prompt_Log, Prompt_History, Prompt_Session, Prompt_Logbook, Prompt_Dialogue, Prompt_Conversation, Prompt_Chat, Prompt_Transcript
export class Tape {
	history: Array<{
		request: Send_Prompt_Message;
		response: Receive_Prompt_Message;
		prompt_response: Receive_Prompt_Message; // TODO with timing and other info?
	}> = [];

	// constructor(options?: {}) {}
}
