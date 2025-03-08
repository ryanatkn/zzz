import {test, expect, vi} from 'vitest';

import {Message} from '$lib/message.svelte.js';
import {Completion_Request} from '$lib/message_types.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {Datetime_Now, Uuid} from '$lib/zod_helpers.js';

// Mock Zzz instance
const create_mock_zzz = () => {
	return {
		registry: {
			instantiate: vi.fn(),
		},
	} as unknown as Zzz;
};

test('Message - JSON serialization excludes undefined values correctly', () => {
	// Create a mock Zzz instance
	const mock_zzz = create_mock_zzz();

	// Create a ping message (simplest case)
	const ping_message = new Message({
		zzz: mock_zzz,
		json: {
			type: 'ping',
			direction: 'client',
		},
	});

	// Create a more complex message type
	const completion_request: Completion_Request = {
		created: Datetime_Now.parse(undefined),
		request_id: Uuid.parse(undefined),
		provider_name: 'ollama',
		model: 'llama3',
		prompt: 'Hello world',
	};

	const prompt_message = new Message({
		zzz: mock_zzz,
		json: {
			type: 'send_prompt',
			direction: 'client',
			completion_request,
		},
	});

	// Test a ping message JSON
	const ping_json = ping_message.to_json();
	expect(ping_json.type).toBe('ping');
	expect(ping_json.direction).toBe('client');
	expect(ping_json.completion_request).toBeUndefined();
	expect(ping_json.completion_response).toBeUndefined();
	expect(ping_json.ping_id).toBeUndefined();
	expect(ping_json.path).toBeUndefined();
	expect(ping_json.contents).toBeUndefined();
	expect(ping_json.change).toBeUndefined();
	expect(ping_json.source_file).toBeUndefined();
	expect(ping_json.data).toBeUndefined();

	// Test a more complex message type
	const prompt_json = prompt_message.to_json();
	expect(prompt_json.type).toBe('send_prompt');
	expect(prompt_json.direction).toBe('client');
	expect(prompt_json.completion_request).toEqual(completion_request);
	expect(prompt_json.completion_response).toBeUndefined();
	expect(prompt_json.ping_id).toBeUndefined();
	expect(prompt_json.path).toBeUndefined();
	expect(prompt_json.contents).toBeUndefined();
	expect(prompt_json.change).toBeUndefined();
	expect(prompt_json.source_file).toBeUndefined();
	expect(prompt_json.data).toBeUndefined();

	// Verify serialization removes undefined values
	const serialized_ping = JSON.stringify(ping_message);
	const parsed_ping = JSON.parse(serialized_ping);
	expect(parsed_ping.completion_request).toBeUndefined();
	expect(parsed_ping.completion_response).toBeUndefined();
	expect(parsed_ping.ping_id).toBeUndefined();
	expect(parsed_ping.path).toBeUndefined();
	expect(parsed_ping.contents).toBeUndefined();
	expect(parsed_ping.change).toBeUndefined();
	expect(parsed_ping.source_file).toBeUndefined();
	expect(parsed_ping.data).toBeUndefined();
});
