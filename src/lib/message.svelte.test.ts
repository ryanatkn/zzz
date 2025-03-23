// @vitest-environment jsdom

import {test, expect} from 'vitest';

import {Message} from '$lib/message.svelte.js';
import {Zzz} from '$lib/zzz.svelte.js';

// Add a basic test that the Message class can be instantiated with minimal data
test('Message - can be instantiated with minimal data', () => {
	const zzz = new Zzz();

	const ping_message = new Message({
		zzz,
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
