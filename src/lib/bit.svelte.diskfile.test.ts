// @vitest-environment jsdom

import {test, expect, describe, beforeEach} from 'vitest';

import {create_uuid, get_datetime_now} from '$lib/zod_helpers.js';
import {Zzz} from '$lib/zzz.svelte.js';
import {Diskfile_Path} from '$lib/diskfile_types.js';
import type {Diskfile} from '$lib/diskfile.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Test data constants for reuse
const TEST_PATHS = {
	BASIC: Diskfile_Path.parse('/test/file.txt'),
	CONFIG: Diskfile_Path.parse('/test/config.json'),
	EMPTY: Diskfile_Path.parse('/test/empty.txt'),
	DOCUMENT: Diskfile_Path.parse('/test/document.txt'),
	EDITABLE: Diskfile_Path.parse('/test/editable.txt'),
	NONEXISTENT: Diskfile_Path.parse('/nonexistent/file.txt'),
	SPECIAL_CHARS: Diskfile_Path.parse('/test/path with spaces & special chars!.txt'),
	BINARY: Diskfile_Path.parse('/test/binary.bin'),
	REACTIVE: Diskfile_Path.parse('/test/reactive.txt'),
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
let zzz: Zzz;
let test_diskfiles: Map<Diskfile_Path, Diskfile>;

// Setup function to create a real Zzz instance and test diskfiles
beforeEach(() => {
	// Create a real Zzz instance
	zzz = monkeypatch_zzz_for_tests(new Zzz());
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
		const diskfile = zzz.diskfiles.add(
			zzz.registry.instantiate('Diskfile', {
				path,
				content,
			}),
		);

		// Store for our test reference
		test_diskfiles.set(path, diskfile);
	}
});

describe('Diskfile_Bit initialization', () => {
	test('creates with minimal values when only path provided', () => {
		const path = TEST_PATHS.BASIC;

		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path,
		});

		expect(bit.type).toBe('diskfile');
		expect(bit.path).toBe(path);
		expect(bit.name).toBe('');
		expect(bit.enabled).toBe(true);
		expect(bit.has_xml_tag).toBe(true);
		expect(bit.xml_tag_name).toBe('');
		expect(bit.attributes).toEqual([]);
		expect(bit.start).toBeNull();
		expect(bit.end).toBeNull();
	});

	test('initializes from json with complete properties', () => {
		const test_id = create_uuid();
		const test_path = TEST_PATHS.CONFIG;
		const test_date = get_datetime_now();

		const bit = zzz.registry.instantiate('Diskfile_Bit', {
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

		expect(bit.id).toBe(test_id);
		expect(bit.created).toBe(test_date);
		expect(bit.path).toBe(test_path);
		expect(bit.name).toBe('Config file');
		expect(bit.has_xml_tag).toBe(true);
		expect(bit.xml_tag_name).toBe('config');
		expect(bit.title).toBe('Configuration');
		expect(bit.summary).toBe('System configuration file');
		expect(bit.start).toBe(5);
		expect(bit.end).toBe(20);
		expect(bit.enabled).toBe(false);
		expect(bit.attributes).toHaveLength(1);
		expect(bit.attributes[0].key).toBe('format');
		expect(bit.attributes[0].value).toBe('json');
	});

	test('initializes with null path', () => {
		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: null,
		});

		expect(bit.path).toBeNull();
		expect(bit.diskfile).toBeNull();
		expect(bit.content).toBeUndefined();
	});
});

describe('Diskfile_Bit content access', () => {
	test('content getter returns diskfile content', () => {
		const path = TEST_PATHS.DOCUMENT;
		const content = TEST_CONTENT.DOCUMENT;

		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path,
		});

		expect(bit.content).toBe(content);
		expect(bit.diskfile).toEqual(test_diskfiles.get(path));
	});

	test('content setter updates diskfile content', () => {
		const path = TEST_PATHS.EDITABLE;
		const initial_content = TEST_CONTENT.EDITABLE.INITIAL;
		const updated_content = TEST_CONTENT.EDITABLE.UPDATED;

		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path,
		});

		// Verify initial state
		expect(bit.content).toBe(initial_content);

		// Update content
		bit.content = updated_content;

		// Verify diskfile was updated - get it fresh from zzz
		const diskfile = zzz.diskfiles.get_by_path(path);
		expect(diskfile?.content).toBe(updated_content);
		expect(bit.content).toBe(updated_content);
	});

	test('assigning bit content updates diskfile content', () => {
		const path = TEST_PATHS.EDITABLE;
		const initial_content = TEST_CONTENT.EDITABLE.INITIAL;
		const updated_content = TEST_CONTENT.EDITABLE.UPDATED;

		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path,
		});

		// Verify initial state
		expect(bit.content).toBe(initial_content);

		// Update content using assignment
		bit.content = updated_content;

		// Verify diskfile was updated - get it fresh from zzz
		const diskfile = zzz.diskfiles.get_by_path(path);
		expect(diskfile?.content).toBe(updated_content);
		expect(bit.content).toBe(updated_content);
	});

	test('content is undefined when diskfile not found', () => {
		const path = TEST_PATHS.NONEXISTENT;

		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path,
		});

		expect(bit.diskfile).toBeUndefined();
		expect(bit.content).toBeUndefined();
	});

	test('setting content to null logs error in development', () => {
		const path = TEST_PATHS.BASIC;
		const bit = zzz.registry.instantiate('Diskfile_Bit', {
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
		bit.content = null as any;

		// Restore console.error
		console.error = original_console_error;

		// Verify error was logged
		expect(error_called).toBe(true);

		// Verify diskfile content was not changed
		const diskfile = test_diskfiles.get(path);
		expect(diskfile?.content).toBe(TEST_CONTENT.BASIC);
	});
});

describe('Diskfile_Bit reactive properties', () => {
	test('derived properties update when diskfile content changes', () => {
		const path = TEST_PATHS.REACTIVE;
		const initial_content = TEST_CONTENT.REACTIVE.INITIAL;
		const updated_content = TEST_CONTENT.REACTIVE.UPDATED;

		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path,
		});

		// Verify initial state
		expect(bit.content).toBe(initial_content);
		expect(bit.length).toBe(initial_content.length);

		// Update diskfile content directly
		bit.diskfile!.content = updated_content;

		// Verify derived properties update
		expect(bit.content).toBe(updated_content);
		expect(bit.length).toBe(updated_content.length);
	});

	test('derived properties update when path changes', () => {
		const path1 = TEST_PATHS.BASIC;
		const path2 = TEST_PATHS.CONFIG;

		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: path1,
		});

		// Verify initial state
		expect(bit.content).toBe(TEST_CONTENT.BASIC);

		// Change path
		bit.path = path2;

		// Verify derived properties update
		expect(bit.content).toBe(TEST_CONTENT.CONFIG);
		expect(bit.diskfile).toEqual(test_diskfiles.get(path2));
	});
});

describe('Diskfile_Bit serialization', () => {
	test('to_json includes all properties with correct values', () => {
		const test_id = create_uuid();
		const path = TEST_PATHS.BASIC;
		const created = get_datetime_now();

		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			id: test_id,
			created,
			type: 'diskfile',
			path,
			name: 'Test file',
			start: 10,
			end: 20,
		});

		const json = bit.to_json();

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

		const original = zzz.registry.instantiate('Diskfile_Bit', {
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

describe('Diskfile_Bit edge cases', () => {
	test('handles special characters in path', () => {
		const path = TEST_PATHS.SPECIAL_CHARS;

		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path,
		});

		expect(bit.path).toBe(path);
		expect(bit.content).toBe(TEST_CONTENT.BASIC);
		expect(bit.diskfile).toEqual(test_diskfiles.get(path));
	});

	test('handles empty content', () => {
		const path = TEST_PATHS.EMPTY;
		const diskfile = test_diskfiles.get(path)!;
		diskfile.content = '';

		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path,
		});

		expect(bit.content).toBe('');
		expect(bit.length).toBe(0);
		expect(bit.token_count).toBe(0);
	});

	test('handles binary file content', () => {
		const path = TEST_PATHS.BINARY;
		const binary_content = TEST_CONTENT.BINARY;
		const diskfile = test_diskfiles.get(path)!;
		diskfile.content = binary_content;

		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path,
		});

		expect(bit.content).toBe(binary_content);
		expect(bit.length).toBe(binary_content.length);
	});

	test('handles changing from null path to valid path', () => {
		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: null,
		});

		// Verify initial state
		expect(bit.path).toBeNull();
		expect(bit.diskfile).toBeNull();
		expect(bit.content).toBeUndefined();

		// Set to valid path
		const path = TEST_PATHS.BASIC;
		bit.path = path;

		// Verify properties updated
		expect(bit.path).toBe(path);
		expect(bit.diskfile?.id).toBe(test_diskfiles.get(path)?.id);
		expect(bit.content).toBe(TEST_CONTENT.BASIC);
	});

	test('handles changing from valid path to null path', () => {
		const path = TEST_PATHS.BASIC;
		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path,
		});

		// Verify initial state
		expect(bit.path).toBe(path);
		expect(bit.diskfile?.id).toBe(test_diskfiles.get(path)?.id);

		// Set to null path
		bit.path = null;

		// Verify properties updated
		expect(bit.path).toBeNull();
		expect(bit.diskfile).toBeNull();
		expect(bit.content).toBeUndefined();
	});
});

describe('Diskfile_Bit attribute management', () => {
	test('can add, update and remove attributes', () => {
		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: TEST_PATHS.BASIC,
		});

		// Add attribute
		bit.add_attribute({key: 'mime-type', value: 'text/plain'});
		expect(bit.attributes).toHaveLength(1);
		expect(bit.attributes[0].key).toBe('mime-type');
		expect(bit.attributes[0].value).toBe('text/plain');

		const attr_id = bit.attributes[0].id;

		// Update attribute
		const updated = bit.update_attribute(attr_id, {value: 'application/text'});
		expect(updated).toBe(true);
		expect(bit.attributes[0].key).toBe('mime-type');
		expect(bit.attributes[0].value).toBe('application/text');

		// Remove attribute
		bit.remove_attribute(attr_id);
		expect(bit.attributes).toHaveLength(0);

		// Attempting to update non-existent attribute returns false
		const fake_update = bit.update_attribute(create_uuid(), {key: 'test', value: 'test'});
		expect(fake_update).toBe(false);
	});

	test('updates attribute key and value together', () => {
		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: TEST_PATHS.BASIC,
		});

		bit.add_attribute({key: 'class', value: 'highlight'});
		const attr_id = bit.attributes[0].id;

		// Update both key and value
		const updated = bit.update_attribute(attr_id, {key: 'data-type', value: 'important'});
		expect(updated).toBe(true);
		expect(bit.attributes[0].key).toBe('data-type');
		expect(bit.attributes[0].value).toBe('important');
	});

	test('attributes are preserved when serializing to JSON', () => {
		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: TEST_PATHS.BASIC,
		});

		bit.add_attribute({key: 'data-test', value: 'true'});
		bit.add_attribute({key: 'class', value: 'important'});

		const json = bit.to_json();

		expect(json.attributes).toHaveLength(2);
		expect(json.attributes[0].key).toBe('data-test');
		expect(json.attributes[1].key).toBe('class');

		// Verify they're properly restored
		const new_bit = zzz.registry.instantiate('Diskfile_Bit', json);

		expect(new_bit.attributes).toHaveLength(2);
		expect(new_bit.attributes[0].key).toBe('data-test');
		expect(new_bit.attributes[1].key).toBe('class');
	});
});

describe('Diskfile_Bit position markers', () => {
	test('start and end positions are initialized properly', () => {
		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: TEST_PATHS.BASIC,
			start: 10,
			end: 25,
		});

		expect(bit.start).toBe(10);
		expect(bit.end).toBe(25);
	});

	test('start and end positions can be updated', () => {
		const bit = zzz.registry.instantiate('Diskfile_Bit', {
			type: 'diskfile',
			path: TEST_PATHS.BASIC,
		});

		// Initial values are null
		expect(bit.start).toBeNull();
		expect(bit.end).toBeNull();

		// Update positions
		bit.start = 5;
		bit.end = 15;

		expect(bit.start).toBe(5);
		expect(bit.end).toBe(15);
	});
});
