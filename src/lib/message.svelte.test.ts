import {test, expect, vi} from 'vitest';

import {Message} from '$lib/message.svelte.js';
import type {Zzz} from '$lib/zzz.svelte.js';

// Mock Zzz instance
const create_mock_zzz = () => {
	return {
		registry: {
			instantiate: vi.fn(),
		},
	} as unknown as Zzz;
};

// Add a basic test that the Message class can be instantiated with minimal data
test('Message - can be instantiated with minimal data', () => {
	const mock_zzz = create_mock_zzz();

	const ping_message = new Message({
		zzz: mock_zzz,
		json: {
			type: 'ping',
			direction: 'client',
		},
	});

	expect(ping_message.type).toBe('ping');
	expect(ping_message.direction).toBe('client');
	expect(ping_message.is_ping).toBe(true);
	expect(ping_message.is_pong).toBe(false);
});
