// @vitest-environment jsdom

import {test, expect} from 'vitest';

import {Payload} from '$lib/payload.svelte.js';
import {Zzz} from '$lib/zzz.svelte.js';

// Add a basic test that the Payload class can be instantiated with minimal data
test('Payload - can be instantiated with minimal data', () => {
	const zzz = new Zzz();

	const ping_payload = new Payload({
		zzz,
		json: {
			type: 'ping',
			direction: 'client',
		},
	});

	expect(ping_payload.type).toBe('ping');
	expect(ping_payload.direction).toBe('client');
	expect(ping_payload.is_ping).toBe(true);
	expect(ping_payload.is_pong).toBe(false);
});
