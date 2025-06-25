// @slop claude_sonnet_4

// @vitest-environment jsdom

import {test, expect, describe} from 'vitest';

import {Ollama, Ollama_Operation} from '$lib/ollama.svelte.js';
import {create_uuid} from '$lib/zod_helpers.js';
import {Frontend} from '$lib/frontend.svelte.js';
import config from '$lib/config.js';

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

		expect(ollama.host).toBe('http://127.0.0.1:11434');
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
			ollama_details_loaded: true,
			ollama_details: {license: 'MIT'},
		});

		const ollama = new Ollama({app});
		const model = app.models.find_by_name('test_model');

		expect(model).toBeDefined();
		expect(model!.ollama_details_loaded).toBe(true);
		expect(model!.ollama_details).toEqual({license: 'MIT'});

		ollama.clear_model_details('test_model');

		expect(model!.ollama_details).toBeUndefined();
		expect(model!.ollama_details_loaded).toBe(false);
		expect(model!.ollama_details_error).toBeUndefined();
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

		operation.update_progress(50);
		expect(operation.progress).toBe(50);

		// Test bounds
		operation.update_progress(150);
		expect(operation.progress).toBe(100);

		operation.update_progress(-10);
		expect(operation.progress).toBe(0);
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
});
