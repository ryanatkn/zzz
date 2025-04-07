// @vitest-environment jsdom

import {test, expect} from 'vitest';

import {Action} from '$lib/action.svelte.js';
import {Zzz} from '$lib/zzz.svelte.js';

// Add a basic test that the Action class can be instantiated with minimal data
test('Action - can be instantiated with minimal data', () => {
	const zzz = new Zzz();

	const ping_action = new Action({
		zzz,
		json: {
			type: 'ping',
			direction: 'client',
		},
	});

	expect(ping_action.type).toBe('ping');
	expect(ping_action.direction).toBe('client');
	expect(ping_action.is_ping).toBe(true);
	expect(ping_action.is_pong).toBe(false);
});
