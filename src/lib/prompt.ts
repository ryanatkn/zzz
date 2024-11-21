export interface Prompt {
	messages: Prompt_Message[];
}

export interface Prompt_Message {
	role: 'user' | 'system';
	content: Prompt_Message_Content[];
}

export type Prompt_Message_Content = string; // TODO ?
