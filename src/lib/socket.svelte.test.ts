// @vitest-environment jsdom

import {beforeEach, describe, test, expect, vi, afterEach} from 'vitest';

import {Socket} from '$lib/socket.svelte.js';
import {DEFAULT_CLOSE_CODE} from '$lib/socket_helpers.js';

// Mock WebSocket
class MockWebSocket {
	listeners: Record<string, Array<(event: any) => void> | undefined> = {
		open: [],
		close: [],
		error: [],
		message: [],
	};
	url: string;
	readyState: number = 0; // CONNECTING
	sent_messages: Array<string> = [];
	close_code: number | null = null;

	constructor(url: string) {
		this.url = url;
	}

	addEventListener(type: string, listener: (event: any) => void) {
		if (!this.listeners[type]) {
			this.listeners[type] = [];
		}
		this.listeners[type].push(listener);
	}

	removeEventListener(type: string, listener: (event: any) => void) {
		if (!this.listeners[type]) return;
		this.listeners[type] = this.listeners[type].filter((l) => l !== listener);
	}

	dispatchEvent(type: string, event: any = {}) {
		if (!this.listeners[type]) return;
		for (const listener of this.listeners[type]) {
			listener(event);
		}
	}

	send(data: string) {
		this.sent_messages.push(data);
	}

	close(code: number = 1000) {
		this.close_code = code;
		this.readyState = 3; // CLOSED
		this.dispatchEvent('close', {code});
	}

	// Helper to simulate connection
	connect() {
		this.readyState = 1; // OPEN
		this.dispatchEvent('open', {});
	}
}

describe('Socket', () => {
	let original_web_socket: typeof WebSocket;
	let mock_socket: MockWebSocket;
	let mock_zzz: any;

	// Setup mock
	beforeEach(() => {
		original_web_socket = window.WebSocket;
		mock_socket = new MockWebSocket('ws://test.com');

		// Mock zzz object with send_ping method
		mock_zzz = {
			cells: new Map(),
			send_ping: vi.fn(),
			time: {
				now_ms: Date.now(),
				interval: 1000,
			},
		};

		window.WebSocket = vi.fn().mockImplementation((url) => {
			mock_socket.url = url;
			return mock_socket;
		}) as any;

		// Mock setTimeout and clearTimeout to control timing
		vi.useFakeTimers();
	});

	// Restore original WebSocket
	afterEach(() => {
		window.WebSocket = original_web_socket;
		vi.restoreAllMocks();
		vi.useRealTimers();
	});

	test('connect - creates WebSocket with provided URL', () => {
		const socket = new Socket({zzz: mock_zzz});
		socket.connect('ws://localhost:1234');

		expect(window.WebSocket).toHaveBeenCalledWith('ws://localhost:1234');
		expect(socket.url).toBe('ws://localhost:1234');
		expect(socket.status).toBe('pending');
	});

	test('disconnect - closes WebSocket with default close code', () => {
		const socket = new Socket({zzz: mock_zzz});
		socket.connect('ws://localhost:1234');

		// Need to mock open first so the close is actually called
		mock_socket.connect();

		// Now when we disconnect, the close should be called
		socket.disconnect();

		expect(mock_socket.close_code).toBe(DEFAULT_CLOSE_CODE);
		expect(socket.ws).toBeNull();
		expect(socket.open).toBe(false);
	});

	test('connection succeeds - updates state accordingly', () => {
		const socket = new Socket({zzz: mock_zzz});
		socket.connect('ws://localhost:1234');
		mock_socket.connect();

		expect(socket.open).toBe(true);
		expect(socket.status).toBe('success');
		expect(socket.connected).toBe(true);
	});

	test('send - queues message when socket is not connected', () => {
		const socket = new Socket({zzz: mock_zzz});
		const test_data = {type: 'test', data: 'message'};

		// Not connected yet
		const sent = socket.send(test_data);
		expect(sent).toBe(false);
		expect(socket.queued_message_count).toBe(1);
	});

	test('send - sends message when socket is connected', () => {
		const socket = new Socket({zzz: mock_zzz});
		socket.connect('ws://localhost:1234');
		mock_socket.connect();

		const test_data = {type: 'test', data: 'message'};
		const sent = socket.send(test_data);

		expect(sent).toBe(true);
		expect(mock_socket.sent_messages.length).toBe(1);
		expect(JSON.parse(mock_socket.sent_messages[0])).toEqual(test_data);
	});

	test('auto reconnect - attempts to reconnect after close', () => {
		const socket = new Socket({zzz: mock_zzz});
		socket.reconnect_delay = 1000; // 1 second
		socket.connect('ws://localhost:1234');
		mock_socket.connect();

		// Simulate unexpected close
		mock_socket.dispatchEvent('close');

		expect(socket.open).toBe(false);
		expect(socket.status).toBe('failure');

		// WebSocket constructor should be called again after delay
		vi.advanceTimersByTime(1000);
		expect(window.WebSocket).toHaveBeenCalledTimes(2);
	});

	test('reconnect delay - uses exponential backoff', () => {
		const socket = new Socket({zzz: mock_zzz});
		// Set up consistent values for testing
		socket.reconnect_delay = 1000; // base delay 1 second
		socket.reconnect_delay_max = 30000; // max 30 seconds

		// First connect and establish a success state
		socket.connect('ws://localhost:1234');
		mock_socket.connect();
		expect(socket.status).toBe('success');

		// First unexpected close - should use base delay (1000ms)
		mock_socket.dispatchEvent('close', {code: 1006});
		expect(socket.status).toBe('failure');
		expect(socket.reconnect_count).toBe(1);
		expect(socket.current_reconnect_delay).toBe(1000); // 1000 * 1.5^0

		// Let timeout elapse, which should trigger a reconnection attempt
		vi.advanceTimersByTime(1000);
		expect(window.WebSocket).toHaveBeenCalledTimes(2);

		// For testing the backoff, we'll simulate consecutive failure scenarios
		// without letting the socket successfully connect between attempts

		// To test the second attempt, we need to:
		// 1. Create a new socket instance to avoid the success state resetting counter
		// 2. Or manually force the reconnect mechanism

		// Let's use direct access to test the sequential reconnect behavior

		// Force socket into failure state with reconnect_count = 1
		socket.disconnect();
		socket.status = 'failure';
		socket.reconnect_count = 1;

		// Manually trigger reconnect logic to see delay for attempt #2
		// We're using a hacky approach to trigger the socket's private reconnect method
		socket.maybe_reconnect();
		expect(socket.reconnect_count).toBe(2);
		expect(socket.current_reconnect_delay).toBe(1500); // 1000 * 1.5^1

		// Clear current timeout to avoid interference
		if (socket.reconnect_timeout !== null) {
			window.clearTimeout(socket.reconnect_timeout);
		}

		// Force socket into failure state with reconnect_count = 2
		socket.status = 'failure';
		socket.reconnect_count = 2;

		// Trigger reconnect logic to see delay for attempt #3
		socket.maybe_reconnect();
		expect(socket.reconnect_count).toBe(3);
		expect(socket.current_reconnect_delay).toBe(2250); // 1000 * 1.5^2

		// Clear current timeout to avoid interference
		if (socket.reconnect_timeout !== null) {
			window.clearTimeout(socket.reconnect_timeout);
		}

		// Force socket into failure state with reconnect_count = 3
		socket.status = 'failure';
		socket.reconnect_count = 3;

		// Trigger reconnect logic to see delay for attempt #4
		socket.maybe_reconnect();
		expect(socket.reconnect_count).toBe(4);
		expect(socket.current_reconnect_delay).toBe(3375); // 1000 * 1.5^3

		// Test max delay cap
		// Clear current timeout to avoid interference
		if (socket.reconnect_timeout !== null) {
			window.clearTimeout(socket.reconnect_timeout);
		}

		// Set up large reconnect count to test maximum delay cap
		socket.status = 'failure';
		socket.reconnect_count = 14;

		// Trigger reconnect logic to see that delay is capped at max
		socket.maybe_reconnect();
		expect(socket.reconnect_count).toBe(15);
		expect(socket.current_reconnect_delay).toBe(30000); // Should be capped at max
	});

	test('message queueing - sends queued messages when reconnected', () => {
		const socket = new Socket({zzz: mock_zzz});

		// Queue some messages while disconnected
		socket.send({type: 'message1'});
		socket.send({type: 'message2'});

		expect(socket.queued_message_count).toBe(2);

		// Now connect
		socket.connect('ws://localhost:1234');
		mock_socket.connect();

		// Messages should be sent
		expect(mock_socket.sent_messages.length).toBe(2);
		expect(socket.queued_message_count).toBe(0);
	});

	test('heartbeat - sends heartbeat at interval', () => {
		const socket = new Socket({zzz: mock_zzz});
		socket.heartbeat_interval = 1000; // 1 second for testing
		socket.connect('ws://localhost:1234');
		mock_socket.connect();

		// Advance time by the heartbeat interval
		vi.advanceTimersByTime(1000);

		// Check that the send_ping method was called
		expect(mock_zzz.send_ping).toHaveBeenCalled();
	});

	test('failed messages - moves message to failed when send throws error', () => {
		const socket = new Socket({zzz: mock_zzz});

		// Queue a message
		socket.send({type: 'test_message'});
		expect(socket.queued_message_count).toBe(1);

		// Mock a scenario where send fails when connected
		const mock_error = new Error('Send failed');
		mock_socket.send = vi.fn().mockImplementation(() => {
			throw mock_error;
		});

		// Connect and let it try to send
		socket.connect('ws://localhost:1234');
		mock_socket.connect();

		// Message should be moved directly to failed messages
		expect(socket.queued_message_count).toBe(0);
		expect(socket.failed_message_count).toBe(1);

		// Check reason in failed message
		const failed_message = Array.from(socket.failed_messages.values())[0];
		expect(failed_message.reason).toBe('Send failed');
	});

	test('clear_failed_messages - removes all failed messages', () => {
		const socket = new Socket({zzz: mock_zzz});

		// First queue a message while disconnected
		socket.send({type: 'will_fail'});
		expect(socket.queued_message_count).toBe(1);

		// Mock WebSocket's send to throw an error
		mock_socket.send = vi.fn().mockImplementation(() => {
			throw new Error('Send failed');
		});

		// Connect which should trigger processing of queued messages
		socket.connect('ws://localhost:1234');
		mock_socket.connect();

		// Explicitly call retry to ensure messages are processed
		socket.retry_queued_messages();

		// Now the message should be in failed messages
		expect(socket.queued_message_count).toBe(0);
		expect(socket.failed_message_count).toBe(1);

		// Clear failed messages
		socket.clear_failed_messages();
		expect(socket.failed_message_count).toBe(0);
	});

	test('request - resolves when matching response received', async () => {
		const socket = new Socket({zzz: mock_zzz});
		socket.connect('ws://localhost:1234');
		mock_socket.connect();

		// Create a promise that will resolve when the response is received
		const request_promise = socket.request<{type: string; request_id: string; data: string}>(
			{type: 'get_data', id: 'req123'},
			(message) => {
				if (message.type === 'data_response' && message.request_id === 'req123') {
					return message;
				}
				return false;
			},
			1000,
		);

		// Should have sent the request
		expect(mock_socket.sent_messages.length).toBe(1);

		// Simulate receiving a response
		mock_socket.dispatchEvent('message', {
			data: JSON.stringify({type: 'data_response', request_id: 'req123', data: 'test'}),
		});

		const result = await request_promise;
		expect(result.type).toBe('data_response');
		expect(result.data).toBe('test');
	});

	test('update_url - reconnects with new URL if already connected', () => {
		const socket = new Socket({zzz: mock_zzz});
		socket.connect('ws://localhost:1234');
		mock_socket.connect();

		expect(socket.url).toBe('ws://localhost:1234');

		// Update URL
		socket.update_url('ws://newhost:5678');

		expect(socket.url).toBe('ws://newhost:5678');
		expect(window.WebSocket).toHaveBeenCalledTimes(2);
		expect(window.WebSocket).toHaveBeenLastCalledWith('ws://newhost:5678');
	});
});
