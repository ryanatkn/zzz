import {base} from '$app/paths';

import type {Uuid} from '$lib/zod_helpers.js';

// TODO think about refactoring with related code

export const to_chats_url = (chat_id: Uuid | null): string =>
	chat_id ? `${base}/chats/${chat_id}` : `${base}/chats`;

export const to_prompts_url = (chat_id: Uuid | null): string =>
	chat_id ? `${base}/prompts/${chat_id}` : `${base}/prompts`;
