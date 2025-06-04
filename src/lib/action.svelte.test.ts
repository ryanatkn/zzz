// @vitest-environment jsdom

import {test, expect} from 'vitest';

import {Action} from '$lib/action.svelte.js';
import {Zzz_App} from '$lib/zzz_app.svelte.js';

// Add a basic test that the Action class can be instantiated with minimal data
test('Action - can be instantiated with minimal data', () => {
	const app = new Zzz_App();

	const ping_action = new Action({
		app,
		json: {method: 'ping'},
	});

	expect(ping_action.method).toBe('ping');
	expect(ping_action.kind).toBe('request_response');
	expect(ping_action.is_ping).toBe(true);
	expect(ping_action.is_file_related).toBe(false);
});
