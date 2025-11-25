// @slop Claude Sonnet 3.7

// @vitest-environment jsdom

import {test, expect, describe, beforeEach} from 'vitest';

import {Part, TextPart, DiskfilePart} from '$lib/part.svelte.js';
import {create_uuid, get_datetime_now} from '$lib/zod_helpers.js';
import {DiskfileDirectoryPath, DiskfilePath} from '$lib/diskfile_types.js';
import {Frontend} from '$lib/frontend.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';
import {estimate_token_count} from '$lib/helpers.js';

// Test suite variables
let app: Frontend;

// Test constants
const TEST_CONTENT = {
	BASIC: 'Basic test content',
	SECONDARY: 'Secondary test content',
	EMPTY: '',
};

const TEST_PATH = DiskfilePath.parse('/path/to/test/file.txt');
const TEST_DIR = DiskfileDirectoryPath.parse('/path/');

beforeEach(() => {
	// Create a real Zzz instance for each test
	app = monkeypatch_zzz_for_tests(new Frontend());
});

describe('Part base class functionality', () => {
	test('attribute management works across all part types', () => {
		const text_part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.BASIC,
		});

		const diskfile_part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: TEST_PATH,
		});

		for (const part of [text_part, diskfile_part]) {
			part.add_attribute({key: 'test-attr', value: 'test-value'});
			expect(part.attributes).toHaveLength(1);
			let first_attr = part.attributes[0];
			if (!first_attr) throw new Error('Expected first attribute');
			expect(first_attr.key).toBe('test-attr');
			expect(first_attr.value).toBe('test-value');

			const attr_id = first_attr.id;

			const updated = part.update_attribute(attr_id, {value: 'updated-value'});
			expect(updated).toBe(true);
			first_attr = part.attributes[0];
			if (!first_attr) throw new Error('Expected attribute after update');
			expect(first_attr.key).toBe('test-attr');
			expect(first_attr.value).toBe('updated-value');

			part.update_attribute(attr_id, {key: 'updated-key', value: 'updated-value-2'});
			first_attr = part.attributes[0];
			if (!first_attr) throw new Error('Expected attribute after second update');
			expect(first_attr.key).toBe('updated-key');
			expect(first_attr.value).toBe('updated-value-2');

			part.remove_attribute(attr_id);
			expect(part.attributes).toHaveLength(0);

			const non_existent_update = part.update_attribute(create_uuid(), {
				value: 'test',
			});
			expect(non_existent_update).toBe(false);
		}
	});

	test('derived properties work correctly', () => {
		// Create a text part to test length and token properties
		const text_part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.BASIC,
		});

		// Test initial derivations
		expect(text_part.length).toBe(TEST_CONTENT.BASIC.length);
		expect(text_part.token_count).toBe(estimate_token_count(TEST_CONTENT.BASIC));

		// Test derivations after content change
		text_part.content = TEST_CONTENT.SECONDARY;

		expect(text_part.length).toBe(TEST_CONTENT.SECONDARY.length);
		expect(text_part.token_count).toBe(estimate_token_count(TEST_CONTENT.SECONDARY));
	});
});

describe('Part factory method', () => {
	test('Part.create creates the correct part type based on JSON', () => {
		const text_part = Part.create(app, {
			type: 'text',
			content: TEST_CONTENT.BASIC,
			name: 'Text Part',
		});

		const diskfile_part = Part.create(app, {
			type: 'diskfile',
			path: TEST_PATH,
			name: 'Diskfile Part',
		});

		expect(text_part).toBeInstanceOf(TextPart);
		expect(text_part.type).toBe('text');
		expect(text_part.name).toBe('Text Part');
		expect(text_part.content).toBe(TEST_CONTENT.BASIC);

		expect(diskfile_part).toBeInstanceOf(DiskfilePart);
		expect(diskfile_part.type).toBe('diskfile');
		expect(diskfile_part.name).toBe('Diskfile Part');
		expect(diskfile_part.path).toBe(TEST_PATH);
	});

	test('Part.create throws error for unknown part type', () => {
		const invalid_json = {
			type: 'unknown' as const,
		};

		expect(() => Part.create(app, invalid_json as any)).toThrow('Unreachable case: unknown');
	});

	test('Part.create throws error for missing type field', () => {
		const invalid_json = {
			name: 'Test',
		};

		expect(() => Part.create(app, invalid_json as any)).toThrow(
			'Missing required "type" field in part JSON',
		);
	});
});

describe('TextPart specific behavior', () => {
	test('TextPart initialization and content management', () => {
		// Create with constructor
		const part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.BASIC,
		});

		expect(part.type).toBe('text');
		expect(part.content).toBe(TEST_CONTENT.BASIC);

		// Test update method
		part.content = TEST_CONTENT.SECONDARY;
		expect(part.content).toBe(TEST_CONTENT.SECONDARY);

		// Test direct property assignment
		part.content = TEST_CONTENT.EMPTY;
		expect(part.content).toBe(TEST_CONTENT.EMPTY);
	});

	test('TextPart serialization and deserialization', () => {
		const test_id = create_uuid();
		const test_date = get_datetime_now();

		// Create part with all properties
		const original = app.cell_registry.instantiate('TextPart', {
			id: test_id,
			created: test_date,
			type: 'text',
			content: TEST_CONTENT.BASIC,
			name: 'Test part',
			has_xml_tag: true,
			xml_tag_name: 'test',
			start: 5,
			end: 15,
			enabled: false,
			title: 'Test Title',
			summary: 'Test Summary',
		});

		// Add attributes
		original.add_attribute({key: 'class', value: 'highlight'});

		// Serialize to JSON
		const json = original.to_json();

		// Create new part from JSON
		const restored = app.cell_registry.instantiate('TextPart', json);

		// Verify all properties were preserved
		expect(restored.id).toBe(test_id);
		expect(restored.created).toBe(test_date);
		expect(restored.content).toBe(TEST_CONTENT.BASIC);
		expect(restored.name).toBe('Test part');
		expect(restored.has_xml_tag).toBe(true);
		expect(restored.xml_tag_name).toBe('test');
		expect(restored.start).toBe(5);
		expect(restored.end).toBe(15);
		expect(restored.enabled).toBe(false);
		expect(restored.title).toBe('Test Title');
		expect(restored.summary).toBe('Test Summary');
		expect(restored.attributes).toHaveLength(1);
		const restored_attr = restored.attributes[0];
		if (!restored_attr) throw new Error('Expected restored attribute');
		expect(restored_attr.key).toBe('class');
		expect(restored_attr.value).toBe('highlight');
	});

	test('TextPart cloning creates independent copy', () => {
		// Create original part
		const original = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.BASIC,
			name: 'Original',
		});

		// Clone the part
		const clone = original.clone();

		// Verify initial state is the same except id
		expect(clone.id).not.toBe(original.id);
		expect(clone.content).toBe(original.content);
		expect(clone.name).toBe(original.name);

		// Modify clone
		clone.content = TEST_CONTENT.SECONDARY;
		clone.name = 'Modified';

		// Verify original remains unchanged
		expect(original.content).toBe(TEST_CONTENT.BASIC);
		expect(original.name).toBe('Original');

		// Verify clone has new values
		expect(clone.content).toBe(TEST_CONTENT.SECONDARY);
		expect(clone.name).toBe('Modified');
	});
});

describe('DiskfilePart specific behavior', () => {
	test('DiskfilePart initialization and content access', () => {
		// Create a diskfile first
		const diskfile = app.diskfiles.add({
			path: TEST_PATH,
			source_dir: TEST_DIR,
			content: TEST_CONTENT.BASIC,
		});

		// Create diskfile part that references the diskfile
		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: TEST_PATH,
		});

		// Test basic properties
		expect(part.type).toBe('diskfile');
		expect(part.path).toBe(TEST_PATH);
		expect(part.diskfile).toEqual(diskfile);
		expect(part.content).toBe(TEST_CONTENT.BASIC);

		// Update content through part
		part.content = TEST_CONTENT.SECONDARY;

		// Verify both part and diskfile were updated
		expect(part.content).toBe(TEST_CONTENT.SECONDARY);
		expect(part.diskfile?.content).toBe(TEST_CONTENT.SECONDARY);
	});

	test('DiskfilePart handles null path properly', () => {
		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: null,
		});

		expect(part.path).toBeNull();
		expect(part.diskfile).toBeNull();
		expect(part.content).toBeUndefined();
	});

	test('DiskfilePart handles changing path', () => {
		// Create two diskfiles
		const path1 = DiskfilePath.parse('/path/to/file1.txt');
		const path2 = DiskfilePath.parse('/path/to/file2.txt');

		app.diskfiles.add({
			path: path1,
			source_dir: DiskfileDirectoryPath.parse('/path/'),
			content: 'File 1 content',
		});

		app.diskfiles.add({
			path: path2,
			source_dir: DiskfileDirectoryPath.parse('/path/'),
			content: 'File 2 content',
		});

		// Create part referencing first file
		const part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: path1,
		});

		expect(part.path).toBe(path1);
		expect(part.content).toBe('File 1 content');

		// Change path to reference second file
		part.path = path2;

		expect(part.path).toBe(path2);
		expect(part.content).toBe('File 2 content');
	});
});

describe('Common part behavior across types', () => {
	test('Position markers work across part types', () => {
		const text_part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			content: TEST_CONTENT.BASIC,
			start: 5,
			end: 10,
		});

		const diskfile_part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			path: TEST_PATH,
			start: 15,
			end: 20,
		});

		expect(text_part.start).toBe(5);
		expect(text_part.end).toBe(10);

		expect(diskfile_part.start).toBe(15);
		expect(diskfile_part.end).toBe(20);

		text_part.start = 6;
		text_part.end = 11;

		diskfile_part.start = 16;
		diskfile_part.end = 21;

		expect(text_part.start).toBe(6);
		expect(text_part.end).toBe(11);

		expect(diskfile_part.start).toBe(16);
		expect(diskfile_part.end).toBe(21);
	});

	test('XML tag properties work across part types', () => {
		const text_part = app.cell_registry.instantiate('TextPart', {
			type: 'text',
			has_xml_tag: true,
			xml_tag_name: 'text-tag',
		});

		const diskfile_part = app.cell_registry.instantiate('DiskfilePart', {
			type: 'diskfile',
			has_xml_tag: true,
			xml_tag_name: 'file-tag',
		});

		expect(text_part.has_xml_tag).toBe(true);
		expect(text_part.xml_tag_name).toBe('text-tag');

		expect(diskfile_part.has_xml_tag).toBe(true);
		expect(diskfile_part.xml_tag_name).toBe('file-tag');

		text_part.has_xml_tag = false;
		text_part.xml_tag_name = '';

		diskfile_part.xml_tag_name = 'updated-file-tag';

		expect(text_part.has_xml_tag).toBe(false);
		expect(text_part.xml_tag_name).toBe('');

		expect(diskfile_part.has_xml_tag).toBe(true);
		expect(diskfile_part.xml_tag_name).toBe('updated-file-tag');
	});

	test('has_xml_tag defaults correctly for each part type', () => {
		const text_part = app.cell_registry.instantiate('TextPart');
		const diskfile_part = app.cell_registry.instantiate('DiskfilePart');

		expect(text_part.has_xml_tag).toBe(false);
		expect(diskfile_part.has_xml_tag).toBe(true);

		const custom_text_part = app.cell_registry.instantiate('TextPart', {
			has_xml_tag: true,
		});
		const custom_diskfile_part = app.cell_registry.instantiate('DiskfilePart', {
			has_xml_tag: false,
		});

		expect(custom_text_part.has_xml_tag).toBe(true);
		expect(custom_diskfile_part.has_xml_tag).toBe(false);
	});
});
