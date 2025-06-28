// @slop claude_sonnet_4

// @vitest-environment jsdom

import {test, expect, describe, vi} from 'vitest';

import {Ollama, Ollama_Operation} from '$lib/ollama.svelte.js';
import {create_uuid} from '$lib/zod_helpers.js';
import {Frontend} from '$lib/frontend.svelte.js';
import config from '$lib/config.js';
import {OLLAMA_URL} from '$lib/ollama_helpers.js';

describe('Ollama', () => {
	const create_test_app = () => {
		const {providers, models} = config();
		return new Frontend({
			providers,
			models,
		});
	};

	test('should initialize with default values', () => {
		const app = create_test_app();
		const ollama = new Ollama({app});

		expect(ollama.host).toBe(OLLAMA_URL);
		expect(ollama.list_status).toBe('initial');
		expect(ollama.available).toBe(false);
		expect(ollama.models.length).toBeTypeOf('number');
	});

	test('should track operations', () => {
		const app = create_test_app();
		const ollama = new Ollama({app});

		expect(ollama.pending_operations).toHaveLength(0);
		expect(ollama.completed_operations).toHaveLength(0);

		// Add a pending operation
		const id_1 = create_uuid();
		const operation_1 = new Ollama_Operation({
			app,
			json: {
				type: 'pull',
				status: 'pending',
				model: 'test_model_1',
				operation_id: id_1,
			},
		});
		ollama.operations.set(id_1, operation_1);

		expect(ollama.pending_operations).toHaveLength(1);
		expect(ollama.completed_operations).toHaveLength(0);

		// Complete the operation
		operation_1.complete_success();

		expect(ollama.pending_operations).toHaveLength(0);
		expect(ollama.completed_operations).toHaveLength(1);
	});

	test('should clear completed operations', () => {
		const app = create_test_app();
		const ollama = new Ollama({app});

		// Add completed operations
		const id_1 = create_uuid();
		const id_2 = create_uuid();
		const operation_1 = new Ollama_Operation({
			app,
			json: {
				type: 'pull',
				status: 'success',
				model: 'test_model_1',
				operation_id: id_1,
			},
		});
		const operation_2 = new Ollama_Operation({
			app,
			json: {
				type: 'delete',
				status: 'pending',
				model: 'test_model_2',
				operation_id: id_2,
			},
		});

		ollama.operations.set(id_1, operation_1);
		ollama.operations.set(id_2, operation_2);

		expect(ollama.operations.size).toBe(2);

		ollama.clear_completed_operations();

		expect(ollama.operations.size).toBe(1);
		expect(ollama.operations.has(id_2)).toBe(true);
	});

	test('should derive models from app.models', () => {
		const app = create_test_app();

		// Clear existing models and add test models
		app.models.clear();
		app.models.add({name: 'llama3.2:1b', provider_name: 'ollama'});
		app.models.add({name: 'gpt-4', provider_name: 'chatgpt'});
		app.models.add({name: 'gemma3:1b', provider_name: 'ollama'});

		const ollama = new Ollama({app});

		expect(ollama.models).toHaveLength(2);
		expect(ollama.models.length).toBe(2);
		expect(ollama.model_names).toContain('llama3.2:1b');
		expect(ollama.model_names).toContain('gemma3:1b');
		expect(ollama.model_names).not.toContain('gpt-4');
	});

	test('should update derived state correctly', () => {
		const app = create_test_app();

		// Clear and add ollama models
		app.models.clear();
		app.models.add({name: 'model_a', provider_name: 'ollama'});
		app.models.add({name: 'model_b', provider_name: 'ollama'});

		const ollama = new Ollama({app});
		ollama.list_status = 'success';

		expect(ollama.available).toBe(true);
		expect(ollama.models.length).toBe(2);
	});

	test('should clear model details', () => {
		const app = create_test_app();

		// Clear and add a test model with details
		app.models.clear();
		app.models.add({
			name: 'test_model',
			provider_name: 'ollama',
			ollama_show_response_loaded: true,
			ollama_show_response: {license: 'MIT'},
		});

		const ollama = new Ollama({app});
		const model = app.models.find_by_name('test_model');

		expect(model).toBeDefined();
		expect(model!.ollama_show_response_loaded).toBe(true);
		expect(model!.ollama_show_response).toEqual({license: 'MIT'});

		ollama.clear_model_details('test_model');

		expect(model!.ollama_show_response).toBeUndefined();
		expect(model!.ollama_show_response_loaded).toBe(false);
		expect(model!.ollama_show_response_error).toBeUndefined();
	});

	test('should handle model_by_name map', () => {
		const app = create_test_app();

		// Clear and add test models
		app.models.clear();
		app.models.add({name: 'test1', provider_name: 'ollama'});
		app.models.add({name: 'test2', provider_name: 'ollama'});
		app.models.add({name: 'other', provider_name: 'claude'});

		const ollama = new Ollama({app});

		expect(ollama.model_by_name.size).toBe(2);
		expect(ollama.model_by_name.get('test1')?.name).toBe('test1');
		expect(ollama.model_by_name.get('test2')?.name).toBe('test2');
		expect(ollama.model_by_name.has('other')).toBe(false);
	});

	test('should initialize ps state correctly', () => {
		const app = create_test_app();
		const ollama = new Ollama({app});

		expect(ollama.ps_response).toBeNull();
		expect(ollama.ps_status).toBe('initial');
		expect(ollama.ps_error).toBeNull();
		expect(ollama.ps_polling_enabled).toBe(false);
		expect(ollama.ps_polling_interval).toBeNull();
		expect(ollama.running_models).toEqual([]);
		expect(ollama.running_model_names.size).toBe(0);
	});

	test('should derive running models from ps response', () => {
		const app = create_test_app();
		const ollama = new Ollama({app});

		// Set a mock ps response
		ollama.ps_response = {
			models: [
				{
					name: 'llama3.2:1b',
					model: 'llama3.2:1b',
					size: 1024 * 1024 * 1024,
					size_vram: 1024 * 1024 * 1024,
					digest: 'sha256:test1',
					modified_at: '2024-01-01T00:00:00Z',
					expires_at: '2024-01-01T01:00:00Z',
				},
				{
					name: 'gemma:2b',
					model: 'gemma:2b',
					size: 2 * 1024 * 1024 * 1024,
					size_vram: 2 * 1024 * 1024 * 1024,
					digest: 'sha256:test2',
					modified_at: '2024-01-01T00:00:00Z',
					expires_at: '2024-01-01T01:00:00Z',
				},
			],
		};

		expect(ollama.running_models).toHaveLength(2);
		expect(ollama.running_models[0].name).toBe('llama3.2:1b');
		expect(ollama.running_models[0].size_vram).toBe(1024 * 1024 * 1024);
		expect(ollama.running_models[1].name).toBe('gemma:2b');
		expect(ollama.running_models[1].size_vram).toBe(2 * 1024 * 1024 * 1024);

		expect(ollama.running_model_names.has('llama3.2:1b')).toBe(true);
		expect(ollama.running_model_names.has('gemma:2b')).toBe(true);
		expect(ollama.running_model_names.has('other')).toBe(false);
	});

	test('should handle ps polling state', () => {
		const app = create_test_app();
		const ollama = new Ollama({app});

		// Mock window timers
		const setIntervalSpy = vi.spyOn(window, 'setInterval').mockReturnValue(123 as any);
		const clearIntervalSpy = vi.spyOn(window, 'clearInterval');

		// Start polling
		ollama.start_ps_polling();

		expect(ollama.ps_polling_enabled).toBe(true);
		expect(ollama.ps_polling_interval).toBe(123);
		expect(setIntervalSpy).toHaveBeenCalledWith(expect.any(Function), 1000);

		// Starting again should not create another interval
		ollama.start_ps_polling();
		expect(setIntervalSpy).toHaveBeenCalledTimes(1);

		// Stop polling
		ollama.stop_ps_polling();

		expect(ollama.ps_polling_enabled).toBe(false);
		expect(ollama.ps_polling_interval).toBeNull();
		expect(clearIntervalSpy).toHaveBeenCalledWith(123);

		// Stopping again should be safe
		ollama.stop_ps_polling();
		expect(clearIntervalSpy).toHaveBeenCalledTimes(1);

		// Cleanup
		setIntervalSpy.mockRestore();
		clearIntervalSpy.mockRestore();
	});
});

describe('Ollama_Operation', () => {
	const create_test_app = () => {
		const {providers, models} = config();
		return new Frontend({
			providers,
			models,
		});
	};

	test('should handle success completion', () => {
		const app = create_test_app();
		const operation = new Ollama_Operation({
			app,
			json: {
				operation_id: create_uuid(),
				type: 'pull',
				status: 'pending',
				model: 'test_model',
			},
		});

		const result = {type: 'pull' as const, data: {status: 'success'} as any};
		operation.complete_success(result);

		expect(operation.status).toBe('success');
		expect(operation.result).toEqual(result);
		expect(operation.error_message).toBeUndefined();
	});

	test('should handle failure completion', () => {
		const app = create_test_app();
		const operation = new Ollama_Operation({
			app,
			json: {operation_id: create_uuid(), type: 'pull', status: 'pending', model: 'test_model'},
		});

		operation.complete_failure('test error');

		expect(operation.status).toBe('failure');
		expect(operation.error_message).toBe('test error');
		expect(operation.result).toBe(null);
	});

	test('should update progress correctly', () => {
		const app = create_test_app();
		const operation = new Ollama_Operation({
			app,
			json: {operation_id: create_uuid(), type: 'pull', status: 'pending', model: 'test_model'},
		});

		// Normal progress update
		operation.update_progress({status: 'test', completed: 50, total: 100});
		expect(operation.progress_percent).toBe(50);
		expect(operation.progress).toEqual({status: 'test', completed: 50, total: 100});

		// Progress at 100%
		operation.update_progress({status: 'test', completed: 100, total: 100});
		expect(operation.progress_percent).toBe(100);

		// Progress exceeding total (should clamp to 100)
		operation.update_progress({status: 'test', completed: 150, total: 100});
		expect(operation.progress_percent).toBe(100);

		// Negative progress (should clamp to 0)
		operation.update_progress({status: 'test', completed: -10, total: 100});
		expect(operation.progress_percent).toBe(0);

		// Zero total edge case
		operation.update_progress({status: 'test', completed: 50, total: 0});
		expect(operation.progress_percent).toBe(100);

		// Fractional progress
		operation.update_progress({status: 'test', completed: 1, total: 3});
		expect(operation.progress_percent).toBe(33);

		operation.update_progress({status: 'test', completed: 2, total: 3});
		expect(operation.progress_percent).toBe(67);
	});

	test('should handle missing progress fields', () => {
		const app = create_test_app();
		const operation = new Ollama_Operation({
			app,
			json: {operation_id: create_uuid(), type: 'pull', status: 'pending', model: 'test_model'},
		});

		const initial_progress = operation.progress_percent;
		const initial_progress_obj = operation.progress;

		// Should not update if completed is undefined
		operation.update_progress({status: 'test', completed: undefined, total: 100} as any);
		expect(operation.progress_percent).toBe(initial_progress);
		expect(operation.progress).toBe(initial_progress_obj);

		// Should not update if total is undefined
		operation.update_progress({status: 'test', completed: 50, total: undefined} as any);
		expect(operation.progress_percent).toBe(initial_progress);
		expect(operation.progress).toBe(initial_progress_obj);

		// Should not update if both are undefined
		operation.update_progress({status: 'test', completed: undefined, total: undefined} as any);
		expect(operation.progress_percent).toBe(initial_progress);
		expect(operation.progress).toBe(initial_progress_obj);
	});

	test('should be registered in app.cell_registry', () => {
		const app = create_test_app();
		const id = create_uuid();
		const operation = new Ollama_Operation({
			app,
			json: {operation_id: id, type: 'pull', status: 'pending', model: 'test_model'},
		});

		// Operations are cells, so they should be registered
		const found = app.cell_registry.all.get(operation.id);
		expect(found).toBe(operation);
	});

	test('should initialize with correct default values', () => {
		const app = create_test_app();
		const id = create_uuid();
		const operation = new Ollama_Operation({
			app,
			json: {
				operation_id: id,
				type: 'pull',
				status: 'pending',
				model: 'test_model',
			},
		});

		expect(operation.operation_id).toBe(id);
		expect(operation.type).toBe('pull');
		expect(operation.status).toBe('pending');
		expect(operation.model).toBe('test_model');
		expect(operation.progress).toBeUndefined();
		expect(operation.progress_percent).toBeUndefined();
		expect(operation.error_message).toBeUndefined();
		expect(operation.result).toBe(null);
	});

	test('should update timestamps on state changes', () => {
		const app = create_test_app();
		const operation = new Ollama_Operation({
			app,
			json: {operation_id: create_uuid(), type: 'pull', status: 'pending', model: 'test_model'},
		});

		const initial_updated = operation.updated;

		// Wait a bit to ensure timestamp difference
		setTimeout(() => {
			operation.complete_success();
			expect(operation.updated).not.toBe(initial_updated);
		}, 10);
	});

	test('should handle various operation types', () => {
		const app = create_test_app();

		const pull_op = new Ollama_Operation({
			app,
			json: {operation_id: create_uuid(), type: 'pull', status: 'pending', model: 'model1'},
		});
		expect(pull_op.type).toBe('pull');

		const delete_op = new Ollama_Operation({
			app,
			json: {operation_id: create_uuid(), type: 'delete', status: 'pending', model: 'model2'},
		});
		expect(delete_op.type).toBe('delete');

		const copy_op = new Ollama_Operation({
			app,
			json: {operation_id: create_uuid(), type: 'copy', status: 'pending', model: 'model3'},
		});
		expect(copy_op.type).toBe('copy');

		const create_op = new Ollama_Operation({
			app,
			json: {operation_id: create_uuid(), type: 'create', status: 'pending', model: 'model4'},
		});
		expect(create_op.type).toBe('create');

		const list_op = new Ollama_Operation({
			app,
			json: {operation_id: create_uuid(), type: 'list', status: 'pending'},
		});
		expect(list_op.type).toBe('list');
		expect(list_op.model).toBeUndefined();

		const show_op = new Ollama_Operation({
			app,
			json: {operation_id: create_uuid(), type: 'show', status: 'pending', model: 'model5'},
		});
		expect(show_op.type).toBe('show');
	});
});
