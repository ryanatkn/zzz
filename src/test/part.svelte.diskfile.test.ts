// @slop Claude Sonnet 3.7

// @vitest-environment jsdom

import {test, expect, describe, beforeEach} from 'vitest';

import {create_uuid, get_datetime_now} from '$lib/zod_helpers.js';
import {Frontend} from '$lib/frontend.svelte.js';
import {DiskfilePath, SerializableDisknode} from '$lib/diskfile_types.js';
import type {Diskfile} from '$lib/diskfile.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

const TEST_DIR = SerializableDisknode.shape.source_dir.parse('/test/');

// Test data constants for reuse
const TEST_PATHS = {
	BASIC: DiskfilePath.parse(TEST_DIR + 'file.txt'),
	CONFIG: DiskfilePath.parse(TEST_DIR + 'config.json'),
	EMPTY: DiskfilePath.parse(TEST_DIR + 'empty.txt'),
	DOCUMENT: DiskfilePath.parse(TEST_DIR + 'document.txt'),
	EDITABLE: DiskfilePath.parse(TEST_DIR + 'editable.txt'),
	NONEXISTENT: DiskfilePath.parse('/nonexistent/file.txt'),
	SPECIAL_CHARS: DiskfilePath.parse(TEST_DIR + 'path with spaces & special chars!.txt'),
	BINARY: DiskfilePath.parse(TEST_DIR + 'binary.bin'),
	REACTIVE: DiskfilePath.parse(TEST_DIR + 'reactive.txt'),
};

const TEST_CONTENT = {
	BASIC: 'Test content',
	CONFIG: '{"key": "value"}',
	EMPTY: '',
	DOCUMENT: 'File content from diskfile',
	EDITABLE: {
		INITIAL: 'Initial content',
		UPDATED: 'Updated content',
	},
	BINARY: '\x00\x01\x02\xFF\xFE\xFD',
	REACTIVE: {
		INITIAL: 'Initial',
		UPDATED: 'New longer content for testing reactivity',
	},
};

// Test suite variables
let app: Frontend;
let test_diskfiles: Map<DiskfilePath, Diskfile>;

// Setup function to create a real Zzz instance and test diskfiles
beforeEach(() => {
	// Create a real Zzz instance
	app = monkeypatch_zzz_for_tests(new Frontend());
	test_diskfiles = new Map();

	// Create test diskfiles
	for (const [path_key, path] of Object.entries(TEST_PATHS)) {
		if (path_key === 'NONEXISTENT') continue; // Skip nonexistent path

		// Determine content based on path key
		let content = TEST_CONTENT.BASIC;
		if (path_key in TEST_CONTENT) {
			const test_content = TEST_CONTENT[path_key as keyof typeof TEST_CONTENT];
			if (typeof test_content === 'string') {
				content = test_content;
			} else if (typeof test_content === 'object' && 'INITIAL' in test_content) {
				content = test_content.INITIAL;
			}
		}

		// Create the diskfile
		const diskfile = app.diskfiles.add({
			path,
			source_dir: TEST_DIR,
			content,
		});

		// Store for our test reference
		test_diskfiles.set(path, diskfile);
	}
});

describe('DiskfilePart initialization', () => {
	test('creates with minimal values when only path provided', () => {
		const path = TEST_PATHS.BASIC;

		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path,
		});

		expect(part.type).toBe('diskfile');
		expect(part.path).toBe(path);
		expect(part.name).toBe('');
		expect(part.enabled).toBe(true);
		expect(part.has_xml_tag).toBe(true);
		expect(part.xml_tag_name).toBe('');
		expect(part.attributes).toEqual([]);
		expect(part.start).toBeNull();
		expect(part.end).toBeNull();
	});

	test('initializes from json with complete properties', () => {
		const test_id = create_uuid();
		const test_path = TEST_PATHS.CONFIG;
		const test_date = get_datetime_now();

		const part = app.cell_registry.instantiate('DiskfilePart', {
			id: test_id,
			created: test_date,
			type: 'diskfile',
			path: test_path,
			name: 'Config file',
			has_xml_tag: true,
			xml_tag_name: 'config',
			title: 'Configuration',
			summary: 'System configuration file',
			start: 5,
			end: 20,
			enabled: false,
			attributes: [{id: create_uuid(), key: 'format', value: 'json'}],
		});

		expect(part.id).toBe(test_id);
		expect(part.created).toBe(test_date);
		expect(part.path).toBe(test_path);
		expect(part.name).toBe('Config file');
		expect(part.has_xml_tag).toBe(true);
		expect(part.xml_tag_name).toBe('config');
		expect(part.title).toBe('Configuration');
		expect(part.summary).toBe('System configuration file');
		expect(part.start).toBe(5);
		expect(part.end).toBe(20);
		expect(part.enabled).toBe(false);
		expect(part.attributes).toHaveLength(1);
		const first_attr = part.attributes[0];
		if (!first_attr) throw new Error('Expected first attribute');
		expect(first_attr.key).toBe('format');
		expect(first_attr.value).toBe('json');
	});

	test('initializes with null path', () => {
		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: null,
		});

		expect(part.path).toBeNull();
		expect(part.diskfile).toBeNull();
		expect(part.content).toBeUndefined();
	});
});

describe('DiskfilePart content access', () => {
	test('content getter returns diskfile content', () => {
		const path = TEST_PATHS.DOCUMENT;
		const content = TEST_CONTENT.DOCUMENT;

		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path,
		});

		expect(part.content).toBe(content);
		expect(part.diskfile).toEqual(test_diskfiles.get(path));
	});

	test('content setter updates diskfile content', () => {
		const path = TEST_PATHS.EDITABLE;
		const initial_content = TEST_CONTENT.EDITABLE.INITIAL;
		const updated_content = TEST_CONTENT.EDITABLE.UPDATED;

		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path,
		});

		// Verify initial state
		expect(part.content).toBe(initial_content);

		// Update content
		part.content = updated_content;

		// Verify diskfile was updated - get it fresh from zzz
		const diskfile = app.diskfiles.get_by_path(path);
		expect(diskfile?.content).toBe(updated_content);
		expect(part.content).toBe(updated_content);
	});

	test('assigning part content updates diskfile content', () => {
		const path = TEST_PATHS.EDITABLE;
		const initial_content = TEST_CONTENT.EDITABLE.INITIAL;
		const updated_content = TEST_CONTENT.EDITABLE.UPDATED;

		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path,
		});

		// Verify initial state
		expect(part.content).toBe(initial_content);

		// Update content using assignment
		part.content = updated_content;

		// Verify diskfile was updated - get it fresh from zzz
		const diskfile = app.diskfiles.get_by_path(path);
		expect(diskfile?.content).toBe(updated_content);
		expect(part.content).toBe(updated_content);
	});

	test('content is undefined when diskfile not found', () => {
		const path = TEST_PATHS.NONEXISTENT;

		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path,
		});

		expect(part.diskfile).toBeUndefined();
		expect(part.content).toBeUndefined();
	});

	test('setting content to null logs error in development', () => {
		const path = TEST_PATHS.BASIC;
		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path,
		});

		// Save original console.error
		const original_console_error = console.error;
		let error_called = false;

		// Mock console.error
		console.error = () => {
			error_called = true;
		};

		// Try setting to null
		part.content = null as any;

		// Restore console.error
		console.error = original_console_error;

		// Verify error was logged
		expect(error_called).toBe(true);

		// Verify diskfile content was not changed
		const diskfile = test_diskfiles.get(path);
		expect(diskfile?.content).toBe(TEST_CONTENT.BASIC);
	});
});

describe('DiskfilePart reactive properties', () => {
	test('derived properties update when diskfile content changes', () => {
		const path = TEST_PATHS.REACTIVE;
		const initial_content = TEST_CONTENT.REACTIVE.INITIAL;
		const updated_content = TEST_CONTENT.REACTIVE.UPDATED;

		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path,
		});

		// Verify initial state
		expect(part.content).toBe(initial_content);
		expect(part.length).toBe(initial_content.length);

		// Update diskfile content directly
		part.diskfile!.content = updated_content;

		// Verify derived properties update
		expect(part.content).toBe(updated_content);
		expect(part.length).toBe(updated_content.length);
	});

	test('derived properties update when path changes', () => {
		const path1 = TEST_PATHS.BASIC;
		const path2 = TEST_PATHS.CONFIG;

		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: path1,
		});

		// Verify initial state
		expect(part.content).toBe(TEST_CONTENT.BASIC);

		// Change path
		part.path = path2;

		// Verify derived properties update
		expect(part.content).toBe(TEST_CONTENT.CONFIG);
		expect(part.diskfile).toEqual(test_diskfiles.get(path2));
	});
});

describe('DiskfilePart serialization', () => {
	test('to_json includes all properties with correct values', () => {
		const test_id = create_uuid();
		const path = TEST_PATHS.BASIC;
		const created = get_datetime_now();

		const part = app.cell_registry.instantiate('DiskfilePart', {
			id: test_id,
			created,
			type: 'diskfile',
			path,
			name: 'Test file',
			start: 10,
			end: 20,
		});

		const json = part.to_json();

		expect(json.id).toBe(test_id);
		expect(json.type).toBe('diskfile');
		expect(json.created).toBe(created);
		expect(json.path).toBe(path);
		expect(json.name).toBe('Test file');
		expect(json.start).toBe(10);
		expect(json.end).toBe(20);
		expect(json.has_xml_tag).toBe(true);
		expect(json.enabled).toBe(true);
	});

	test('clone creates independent copy with same path', () => {
		const original_path = TEST_PATHS.BASIC;
		const modified_path = TEST_PATHS.CONFIG;

		const original = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: original_path,
			name: 'Original name',
		});

		const clone = original.clone();

		// Verify they have same initial values except id
		expect(clone.id).not.toBe(original.id);
		expect(clone.path).toBe(original_path);
		expect(clone.name).toBe('Original name');

		// Verify they're independent objects
		clone.path = modified_path;
		clone.name = 'Modified name';

		expect(original.path).toBe(original_path);
		expect(original.name).toBe('Original name');
		expect(clone.path).toBe(modified_path);
		expect(clone.name).toBe('Modified name');
	});
});

describe('DiskfilePart edge cases', () => {
	test('handles special characters in path', () => {
		const path = TEST_PATHS.SPECIAL_CHARS;

		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path,
		});

		expect(part.path).toBe(path);
		expect(part.content).toBe(TEST_CONTENT.BASIC);
		expect(part.diskfile).toEqual(test_diskfiles.get(path));
	});

	test('handles empty content', () => {
		const path = TEST_PATHS.EMPTY;
		const diskfile = test_diskfiles.get(path)!;
		diskfile.content = '';

		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path,
		});

		expect(part.content).toBe('');
		expect(part.length).toBe(0);
		expect(part.token_count).toBe(0);
	});

	test('handles binary file content', () => {
		const path = TEST_PATHS.BINARY;
		const binary_content = TEST_CONTENT.BINARY;
		const diskfile = test_diskfiles.get(path)!;
		diskfile.content = binary_content;

		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path,
		});

		expect(part.content).toBe(binary_content);
		expect(part.length).toBe(binary_content.length);
	});

	test('handles changing from null path to valid path', () => {
		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: null,
		});

		// Verify initial state
		expect(part.path).toBeNull();
		expect(part.diskfile).toBeNull();
		expect(part.content).toBeUndefined();

		// Set to valid path
		const path = TEST_PATHS.BASIC;
		part.path = path;

		// Verify properties updated
		expect(part.path).toBe(path);
		expect(part.diskfile?.id).toBe(test_diskfiles.get(path)?.id);
		expect(part.content).toBe(TEST_CONTENT.BASIC);
	});

	test('handles changing from valid path to null path', () => {
		const path = TEST_PATHS.BASIC;
		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path,
		});

		// Verify initial state
		expect(part.path).toBe(path);
		expect(part.diskfile?.id).toBe(test_diskfiles.get(path)?.id);

		// Set to null path
		part.path = null;

		// Verify properties updated
		expect(part.path).toBeNull();
		expect(part.diskfile).toBeNull();
		expect(part.content).toBeUndefined();
	});
});

describe('DiskfilePart attribute management', () => {
	test('can add, update and remove attributes', () => {
		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: TEST_PATHS.BASIC,
		});

		// Add attribute
		part.add_attribute({key: 'mime-type', value: 'text/plain'});
		expect(part.attributes).toHaveLength(1);
		let first_attr = part.attributes[0];
		if (!first_attr) throw new Error('Expected first attribute');
		expect(first_attr.key).toBe('mime-type');
		expect(first_attr.value).toBe('text/plain');

		const attr_id = first_attr.id;

		// Update attribute
		const updated = part.update_attribute(attr_id, {value: 'application/text'});
		expect(updated).toBe(true);
		first_attr = part.attributes[0];
		if (!first_attr) throw new Error('Expected attribute after update');
		expect(first_attr.key).toBe('mime-type');
		expect(first_attr.value).toBe('application/text');

		// Remove attribute
		part.remove_attribute(attr_id);
		expect(part.attributes).toHaveLength(0);

		// Attempting to update non-existent attribute returns false
		const fake_update = part.update_attribute(create_uuid(), {key: 'test', value: 'test'});
		expect(fake_update).toBe(false);
	});

	test('updates attribute key and value together', () => {
		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: TEST_PATHS.BASIC,
		});

		part.add_attribute({key: 'class', value: 'highlight'});
		const first_attr = part.attributes[0];
		if (!first_attr) throw new Error('Expected first attribute');
		const attr_id = first_attr.id;

		// Update both key and value
		const updated = part.update_attribute(attr_id, {key: 'data-type', value: 'important'});
		expect(updated).toBe(true);
		const updated_attr = part.attributes[0];
		if (!updated_attr) throw new Error('Expected attribute after update');
		expect(updated_attr.key).toBe('data-type');
		expect(updated_attr.value).toBe('important');
	});

	test('attributes are preserved when serializing to JSON', () => {
		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: TEST_PATHS.BASIC,
		});

		part.add_attribute({key: 'data-test', value: 'true'});
		part.add_attribute({key: 'class', value: 'important'});

		const json = part.to_json();

		expect(json.attributes).toHaveLength(2);
		const json_attr0 = json.attributes[0];
		const json_attr1 = json.attributes[1];
		if (!json_attr0 || !json_attr1) throw new Error('Expected both attributes in JSON');
		expect(json_attr0.key).toBe('data-test');
		expect(json_attr1.key).toBe('class');

		// Verify they're properly restored
		const new_part = app.cell_registry.instantiate('DiskfilePart', json);

		expect(new_part.attributes).toHaveLength(2);
		const new_attr0 = new_part.attributes[0];
		const new_attr1 = new_part.attributes[1];
		if (!new_attr0 || !new_attr1) throw new Error('Expected both attributes in restored part');
		expect(new_attr0.key).toBe('data-test');
		expect(new_attr1.key).toBe('class');
	});
});

describe('DiskfilePart position markers', () => {
	test('start and end positions are initialized properly', () => {
		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: TEST_PATHS.BASIC,
			start: 10,
			end: 25,
		});

		expect(part.start).toBe(10);
		expect(part.end).toBe(25);
	});

	test('start and end positions can be updated', () => {
		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: TEST_PATHS.BASIC,
		});

		// Initial values are null
		expect(part.start).toBeNull();
		expect(part.end).toBeNull();

		// Update positions
		part.start = 5;
		part.end = 15;

		expect(part.start).toBe(5);
		expect(part.end).toBe(15);
	});
});
