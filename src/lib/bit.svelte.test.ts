// @vitest-environment jsdom

import {test, expect, vi} from 'vitest';
import type {z} from 'zod';
import {encode as tokenize} from 'gpt-tokenizer';

import {
	Bit,
	Text_Bit,
	Diskfile_Bit,
	Sequence_Bit,
	Text_Bit_Json,
	Sequence_Bit_Json,
	Diskfile_Bit_Json,
} from '$lib/bit.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';
import {Diskfile_Path} from '$lib/diskfile_types.js';

// Mock for the Zzz class that includes registry functionality
const create_mock_zzz = (): any => {
	const bits_by_id = new Map();
	const diskfiles_by_path: Map<Diskfile_Path, {path: Diskfile_Path; content: string}> = new Map();
	const registry_classes = new Map();

	// Register the bit classes
	registry_classes.set('Text_Bit', Text_Bit);
	registry_classes.set('Diskfile_Bit', Diskfile_Bit);
	registry_classes.set('Sequence_Bit', Sequence_Bit);

	return {
		cells: new Map(),
		bits: {
			items: {
				by_id: bits_by_id,
				all: [],
				add: (bit: any) => bits_by_id.set(bit.id, bit),
			},
		},
		diskfiles: {
			get_by_path: (path: Diskfile_Path) => diskfiles_by_path.get(path),
			update: (path: Diskfile_Path, content: string) => {
				const diskfile = diskfiles_by_path.get(path);
				if (diskfile) {
					diskfile.content = content;
				}
			},
			add: (path: Diskfile_Path, content: string) => {
				const diskfile = {path, content};
				diskfiles_by_path.set(path, diskfile);
				return diskfile;
			},
		},
		registry: {
			instantiate: (class_name: string, json?: any): any => {
				const Constructor = registry_classes.get(class_name);
				if (!Constructor) return null;
				return new Constructor({zzz: mock_zzz, json});
			},
		},
	};
};

// Create a shared mock zzz for the tests
const mock_zzz = create_mock_zzz();

// Text Bit Tests
test('Text_Bit - basic initialization and properties', () => {
	const json = {content: 'sample content'} satisfies z.input<typeof Text_Bit_Json>;
	const text_bit = mock_zzz.registry.instantiate('Text_Bit', json);

	expect(text_bit.type).toBe('text');
	expect(text_bit.content).toBe(json.content);
	expect(text_bit.length).toBe(json.content.length);
	expect(text_bit.token_count).toBeGreaterThan(0);
	expect(text_bit.name).toBe('');
	expect(text_bit.enabled).toBe(true);
});

test('Text_Bit - initialization from JSON', () => {
	const test_id = Uuid.parse(undefined);
	const json = Text_Bit_Json.parse({
		id: test_id,
		type: 'text',
		created: new Date().toISOString(),
		content: 'json content',
		name: 'test name',
		has_xml_tag: true,
		xml_tag_name: 'test-tag',
		title: 'Test Title',
		summary: 'Test summary',
		start: 0,
		end: 10,
	});

	const text_bit = mock_zzz.registry.instantiate('Text_Bit', json);

	expect(text_bit.id).toBe(json.id);
	expect(text_bit.content).toBe(json.content);
	expect(text_bit.name).toBe(json.name);
	expect(text_bit.has_xml_tag).toBe(json.has_xml_tag);
	expect(text_bit.xml_tag_name).toBe(json.xml_tag_name);
	expect(text_bit.title).toBe(json.title);
	expect(text_bit.summary).toBe(json.summary);
	expect(text_bit.start).toBe(json.start);
	expect(text_bit.end).toBe(json.end);
});

test('Text_Bit - update_content method', () => {
	const text_bit = mock_zzz.registry.instantiate('Text_Bit', {
		type: 'text',
		content: 'initial content',
	});

	text_bit.update_content('updated content');
	expect(text_bit.content).toBe('updated content');
});

// Diskfile Bit Tests
test('Diskfile_Bit - basic initialization and properties', () => {
	const test_path = Diskfile_Path.parse('/path/to/file.txt');
	const test_content = 'file content';
	const json = {path: test_path} as const;

	// Add a diskfile to the mock
	mock_zzz.diskfiles.add(test_path, test_content);

	const diskfile_bit = mock_zzz.registry.instantiate('Diskfile_Bit', json);

	expect(diskfile_bit.type).toBe('diskfile');
	expect(diskfile_bit.path).toBe(json.path);
	expect(diskfile_bit.content).toBe(test_content);
	expect(diskfile_bit.diskfile).toBeDefined();
});

test('Diskfile_Bit - content setter updates diskfile content', () => {
	const test_path = Diskfile_Path.parse('/path/to/file.txt');
	const initial_content = 'initial content';
	const updated_content = 'updated content';

	// Add a diskfile to the mock
	const diskfile = mock_zzz.diskfiles.add(test_path, initial_content);

	const diskfile_bit = mock_zzz.registry.instantiate('Diskfile_Bit', {
		type: 'diskfile',
		path: test_path,
	});

	// Verify initial state
	expect(diskfile_bit.content).toBe(initial_content);

	// Update the content using the setter, which should trigger the diskfile update
	diskfile_bit.content = updated_content;

	// Verify the content was updated through reactivity
	expect(diskfile_bit.content).toBe(updated_content);
	expect(diskfile.content).toBe(updated_content);
});

test('Diskfile_Bit - update_content method', () => {
	const test_path = Diskfile_Path.parse('/path/to/file.txt');
	const initial_content = 'initial content';
	const updated_content = 'updated from method';

	// Add a diskfile to the mock
	const diskfile = mock_zzz.diskfiles.add(test_path, initial_content);

	const diskfile_bit = mock_zzz.registry.instantiate('Diskfile_Bit', {
		type: 'diskfile',
		path: test_path,
	});

	// Update using the method
	diskfile_bit.update_content(updated_content);

	expect(diskfile.content).toBe(updated_content);
	expect(diskfile_bit.content).toBe(updated_content);
});

// Sequence Bit Tests
test('Sequence_Bit - basic initialization and properties', () => {
	// Create a sequence bit with empty items
	const sequence_bit = mock_zzz.registry.instantiate('Sequence_Bit', {});

	expect(sequence_bit.type).toBe('sequence');
	expect(sequence_bit.items).toEqual([]);
	expect(sequence_bit.bits).toEqual([]);
	expect(sequence_bit.content).toBe('');
});

test('Sequence_Bit - initialization with items', () => {
	// Create some referenced bits
	const bit1 = mock_zzz.registry.instantiate('Text_Bit', {
		type: 'text',
		content: 'content 1',
	});

	const bit2 = mock_zzz.registry.instantiate('Text_Bit', {
		type: 'text',
		content: 'content 2',
	});

	// Add to registry
	mock_zzz.bits.items.add(bit1);
	mock_zzz.bits.items.add(bit2);

	const json = {
		type: 'sequence',
		items: [bit1.id, bit2.id],
	} satisfies z.input<typeof Sequence_Bit_Json>;

	// Create sequence with items
	const sequence_bit = mock_zzz.registry.instantiate('Sequence_Bit', json);

	expect(sequence_bit.items).toEqual(json.items);
	expect(sequence_bit.bits).toEqual([bit1, bit2]);
	expect(sequence_bit.content).toBe('content 1\n\ncontent 2');
});

test('Sequence_Bit - item management methods', () => {
	// Create referenced bits
	const bit1 = mock_zzz.registry.instantiate('Text_Bit', {
		type: 'text',
		content: 'content 1',
	});

	const bit2 = mock_zzz.registry.instantiate('Text_Bit', {
		type: 'text',
		content: 'content 2',
	});

	const bit3 = mock_zzz.registry.instantiate('Text_Bit', {
		type: 'text',
		content: 'content 3',
	});

	// Add to registry
	mock_zzz.bits.items.add(bit1);
	mock_zzz.bits.items.add(bit2);
	mock_zzz.bits.items.add(bit3);

	// Create empty sequence
	const sequence_bit = mock_zzz.registry.instantiate('Sequence_Bit', {type: 'sequence'});

	// Test add
	expect(sequence_bit.add(bit1.id)).toBe(true);
	expect(sequence_bit.add(bit2.id)).toBe(true);
	expect(sequence_bit.items).toEqual([bit1.id, bit2.id]);

	// Test adding duplicate (should fail)
	expect(sequence_bit.add(bit1.id)).toBe(false);
	expect(sequence_bit.items).toEqual([bit1.id, bit2.id]);

	// Test move
	expect(sequence_bit.move(bit1.id, 1)).toBe(true);
	expect(sequence_bit.items).toEqual([bit2.id, bit1.id]);

	// Test remove
	expect(sequence_bit.remove(bit2.id)).toBe(true);
	expect(sequence_bit.items).toEqual([bit1.id]);

	// Test removing non-existent item
	expect(sequence_bit.remove(bit2.id)).toBe(false);

	// Test moving non-existent item
	expect(sequence_bit.move(bit2.id, 0)).toBe(false);
});

// Base Bit Tests
test('Bit - attribute management', () => {
	const text_bit = mock_zzz.registry.instantiate('Text_Bit', {
		type: 'text',
		content: 'content',
	});

	// Add an attribute
	text_bit.add_attribute({key: 'attr1', value: 'value1'});
	expect(text_bit.attributes.length).toBe(1);
	expect(text_bit.attributes[0].key).toBe('attr1');
	expect(text_bit.attributes[0].value).toBe('value1');

	const attr_id = text_bit.attributes[0].id;

	// Update the attribute
	const updated = text_bit.update_attribute(attr_id, {value: 'updated-value'});
	expect(updated).toBe(true);
	expect(text_bit.attributes[0].value).toBe('updated-value');
	expect(text_bit.attributes[0].key).toBe('attr1');

	// Update with both key and value
	text_bit.update_attribute(attr_id, {key: 'updated-key', value: 'updated-value-2'});
	expect(text_bit.attributes[0].key).toBe('updated-key');
	expect(text_bit.attributes[0].value).toBe('updated-value-2');

	// Try to update non-existent attribute
	const non_existent_update = text_bit.update_attribute(Uuid.parse(undefined), {
		value: 'test',
	});
	expect(non_existent_update).toBe(false);

	// Remove the attribute
	text_bit.remove_attribute(attr_id);
	expect(text_bit.attributes.length).toBe(0);

	// Removing non-existent attribute should not throw
	expect(() => text_bit.remove_attribute(Uuid.parse(undefined))).not.toThrow();
});

// Bit Factory Method Tests
test('Bit.create - uses registry to create correct bit type based on JSON', () => {
	const spy_instantiate = vi.spyOn(mock_zzz.registry, 'instantiate');

	const text_json: z.input<typeof Text_Bit_Json> = {
		type: 'text',
		content: 'text content',
	};

	const diskfile_path = Diskfile_Path.parse('/path/to/file.txt');
	const diskfile_json: z.input<typeof Diskfile_Bit_Json> = {
		type: 'diskfile',
		path: diskfile_path,
	};

	const sequence_json: z.input<typeof Sequence_Bit_Json> = {
		type: 'sequence',
		items: [],
	};

	// Call the static create method for each type
	Bit.create(mock_zzz, text_json);
	Bit.create(mock_zzz, diskfile_json);
	Bit.create(mock_zzz, sequence_json);

	// Verify the registry was used for instantiation
	expect(spy_instantiate).toHaveBeenCalledTimes(3);
	expect(spy_instantiate).toHaveBeenCalledWith('Text_Bit', text_json);
	expect(spy_instantiate).toHaveBeenCalledWith('Diskfile_Bit', diskfile_json);
	expect(spy_instantiate).toHaveBeenCalledWith('Sequence_Bit', sequence_json);

	spy_instantiate.mockRestore();
});

test('Bit.create - throws error for unknown bit type', () => {
	const invalid_json = {
		type: 'unknown' as const,
	};

	expect(() => Bit.create(mock_zzz, invalid_json as any)).toThrow('Unreachable case: unknown');
});

test('Bit.create - returns typed bit instances', () => {
	// Test text bit
	const text_bit = Bit.create(mock_zzz, {
		type: 'text',
		name: 'My Text',
		content: 'Hello world',
	});
	expect(text_bit).toBeInstanceOf(Text_Bit);
	expect(text_bit.type).toBe('text');
	expect(text_bit.name).toBe('My Text');
	expect(text_bit.content).toBe('Hello world');

	// Test diskfile bit
	const path = Diskfile_Path.parse('/path/to/file.txt');
	const diskfile_bit = Bit.create(mock_zzz, {
		type: 'diskfile',
		path,
		name: 'My File',
	});
	expect(diskfile_bit).toBeInstanceOf(Diskfile_Bit);
	expect(diskfile_bit.type).toBe('diskfile');
	expect(diskfile_bit.name).toBe('My File');
	expect(diskfile_bit.path).toBe(path);
});

test('Bit derived properties - length, tokens, and token_count', () => {
	const test_content = 'Sample content for testing';
	const text_bit = mock_zzz.registry.instantiate('Text_Bit', {
		type: 'text',
		content: test_content,
	});

	expect(text_bit.length).toBe(test_content.length);
	expect(text_bit.tokens).toEqual(tokenize(test_content));
	expect(text_bit.token_count).toBe(tokenize(test_content).length);

	// Test reactivity with content change
	const new_content = 'Different content with more tokens';
	text_bit.content = new_content;

	expect(text_bit.length).toBe(new_content.length);
	expect(text_bit.tokens).toEqual(tokenize(new_content));
	expect(text_bit.token_count).toBe(tokenize(new_content).length);
});

test('Bit serialization preserves properties correctly', () => {
	const test_id = Uuid.parse(undefined);
	const created = new Date().toISOString();

	const text_bit = mock_zzz.registry.instantiate('Text_Bit', {
		id: test_id,
		created,
		type: 'text',
		content: 'Test content',
		name: 'Test bit',
		start: 10,
		end: 20,
		has_xml_tag: true,
		xml_tag_name: 'code',
		enabled: false,
	});

	// Serialize to JSON
	const json = text_bit.to_json();

	// Verify all properties are preserved
	expect(json.id).toBe(test_id);
	expect(json.created).toBe(created);
	expect(json.type).toBe('text');
	expect(json.content).toBe('Test content');
	expect(json.name).toBe('Test bit');
	expect(json.start).toBe(10);
	expect(json.end).toBe(20);
	expect(json.has_xml_tag).toBe(true);
	expect(json.xml_tag_name).toBe('code');
	expect(json.enabled).toBe(false);

	// Create a new instance from the JSON
	const new_bit = mock_zzz.registry.instantiate('Text_Bit', json);

	// Verify properties were restored correctly
	expect(new_bit.id).toBe(test_id);
	expect(new_bit.content).toBe('Test content');
	expect(new_bit.name).toBe('Test bit');
	expect(new_bit.start).toBe(10);
	expect(new_bit.end).toBe(20);
	expect(new_bit.has_xml_tag).toBe(true);
	expect(new_bit.xml_tag_name).toBe('code');
	expect(new_bit.enabled).toBe(false);
});

test('Bit initialization handles missing or null properties', () => {
	// Test with minimal properties
	const minimal_bit = mock_zzz.registry.instantiate('Text_Bit', {
		type: 'text',
	});

	expect(minimal_bit.content).toBe('');
	expect(minimal_bit.name).toBe('');
	expect(minimal_bit.start).toBeNull();
	expect(minimal_bit.end).toBeNull();
	expect(minimal_bit.has_xml_tag).toBe(false);
	expect(minimal_bit.enabled).toBe(true);

	// Test with explicit nulls where allowed
	const nullable_bit = mock_zzz.registry.instantiate('Text_Bit', {
		type: 'text',
		content: 'content',
		start: null,
		end: null,
		title: null,
		summary: null,
	});

	expect(nullable_bit.content).toBe('content');
	expect(nullable_bit.start).toBeNull();
	expect(nullable_bit.end).toBeNull();
	expect(nullable_bit.title).toBeNull();
	expect(nullable_bit.summary).toBeNull();
});
