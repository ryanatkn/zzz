// @vitest-environment jsdom
import {test, expect, describe, vi} from 'vitest';
import {Ollama, Ollama_Operation, Ollama_Model_Detail} from './ollama.svelte.js';
import {create_uuid} from './zod_helpers.js';

// Mock the app object with minimal required properties
const create_mock_app = () =>
	({
		cell_registry: {
			add_cell: vi.fn(),
			remove_cell: vi.fn(),
		},
		time: {
			now_ms: Date.now(),
			interval: 1000,
		},
	}) as any;

describe('Ollama', () => {
	test('should initialize with default values', () => {
		const app = create_mock_app();
		const ollama = new Ollama({app});

		expect(ollama.host).toBe('http://127.0.0.1:11434');
		expect(ollama.auto_refresh).toBe(true);
		expect(ollama.refresh_interval).toBe(30000);
		expect(ollama.list_status).toBe('initial');
		expect(ollama.available).toBe(false);
		expect(ollama.models_count).toBe(0);
	});

	test('should track operations', () => {
		const app = create_mock_app();
		const ollama = new Ollama({app});

		expect(ollama.pending_operations).toHaveLength(0);
		expect(ollama.completed_operations).toHaveLength(0);

		// Add a pending operation
		const operation_1 = new Ollama_Operation({
			app,
			json: {
				type: 'pull',
				status: 'pending',
				model: 'test_model_1',
			},
		});
		const id_1 = create_uuid();
		ollama.operations.set(id_1, operation_1);

		expect(ollama.pending_operations).toHaveLength(1);
		expect(ollama.completed_operations).toHaveLength(0);

		// Complete the operation
		operation_1.complete_success();

		expect(ollama.pending_operations).toHaveLength(0);
		expect(ollama.completed_operations).toHaveLength(1);
	});

	test('should clear completed operations', () => {
		const app = create_mock_app();
		const ollama = new Ollama({app});

		// Add completed operations
		const operation_1 = new Ollama_Operation({
			app,
			json: {
				type: 'pull',
				status: 'success',
				model: 'test_model_1',
			},
		});
		const operation_2 = new Ollama_Operation({
			app,
			json: {
				type: 'delete',
				status: 'pending',
				model: 'test_model_2',
			},
		});

		const id_1 = create_uuid();
		const id_2 = create_uuid();
		ollama.operations.set(id_1, operation_1);
		ollama.operations.set(id_2, operation_2);

		expect(ollama.operations.size).toBe(2);

		ollama.clear_completed_operations();

		expect(ollama.operations.size).toBe(1);
		expect(ollama.operations.has(id_2)).toBe(true);
	});

	test('should manage model details cache', () => {
		const app = create_mock_app();
		const ollama = new Ollama({app});

		// Add model detail
		const detail = new Ollama_Model_Detail({
			app,
			json: {
				model_name: 'test_model',
				last_updated: Date.now(),
			},
		});

		ollama.model_details.set('test_model', detail);

		expect(ollama.model_details.size).toBe(1);

		ollama.clear_model_details_cache();

		expect(ollama.model_details.size).toBe(0);
	});

	test('should update derived state correctly', () => {
		const app = create_mock_app();
		const ollama = new Ollama({app});

		// Simulate a list response
		ollama.list_response = {
			models: [
				{name: 'model_a', size: 1000},
				{name: 'model_b', size: 2000},
			],
		} as any;
		ollama.list_status = 'success';

		expect(ollama.available).toBe(true);
		expect(ollama.models_count).toBe(2);
	});
});

describe('Ollama_Operation', () => {
	test('should handle success completion', () => {
		const app = create_mock_app();
		const operation = new Ollama_Operation({
			app,
			json: {
				type: 'pull',
				status: 'pending',
				model: 'test_model',
			},
		});

		const result = {success: true};
		operation.complete_success(result);

		expect(operation.status).toBe('success');
		expect(operation.result).toEqual(result);
		expect(operation.error_message).toBeUndefined();
	});

	test('should handle failure completion', () => {
		const app = create_mock_app();
		const operation = new Ollama_Operation({
			app,
			json: {
				type: 'pull',
				status: 'pending',
				model: 'test_model',
			},
		});

		operation.complete_failure('test error');

		expect(operation.status).toBe('failure');
		expect(operation.error_message).toBe('test error');
		expect(operation.result).toBeUndefined();
	});

	test('should update progress correctly', () => {
		const app = create_mock_app();
		const operation = new Ollama_Operation({
			app,
			json: {
				type: 'pull',
				status: 'pending',
				model: 'test_model',
			},
		});

		operation.update_progress(50);
		expect(operation.progress).toBe(50);

		// Test bounds
		operation.update_progress(150);
		expect(operation.progress).toBe(100);

		operation.update_progress(-10);
		expect(operation.progress).toBe(0);
	});
});

describe('Ollama_Model_Detail', () => {
	test('should handle loading states', () => {
		const app = create_mock_app();
		const detail = new Ollama_Model_Detail({
			app,
			json: {
				model_name: 'test_model',
				last_updated: Date.now(),
			},
		});

		expect(detail.is_loading).toBe(false);
		expect(detail.has_details).toBe(false);
		expect(detail.has_error).toBe(false);

		detail.start_loading();
		expect(detail.is_loading).toBe(true);
		expect(detail.show_error).toBeUndefined();

		const show_response = {name: 'test_model'} as any;
		detail.complete_loading(show_response);

		expect(detail.is_loading).toBe(false);
		expect(detail.has_details).toBe(true);
		expect(detail.show_response).toEqual(show_response);
	});

	test('should handle loading failure', () => {
		const app = create_mock_app();
		const detail = new Ollama_Model_Detail({
			app,
			json: {
				model_name: 'test_model',
				last_updated: Date.now(),
			},
		});

		detail.start_loading();
		detail.fail_loading('test error');

		expect(detail.is_loading).toBe(false);
		expect(detail.has_error).toBe(true);
		expect(detail.show_error).toBe('test error');
	});

	test('should reset state', () => {
		const app = create_mock_app();
		const detail = new Ollama_Model_Detail({
			app,
			json: {
				model_name: 'test_model',
				last_updated: Date.now(),
			},
		});

		// Set some state
		detail.complete_loading({name: 'test'} as any);
		expect(detail.has_details).toBe(true);

		detail.reset();

		expect(detail.show_response).toBeUndefined();
		expect(detail.show_status).toBe('initial');
		expect(detail.show_error).toBeUndefined();
		expect(detail.has_details).toBe(false);
	});
});
