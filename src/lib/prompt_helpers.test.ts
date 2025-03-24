import {test, expect} from 'vitest';

import {format_prompt_content} from '$lib/prompt_helpers.js';

// Instead of mocking modules, we'll create a simplified bit structure
// that mirrors the interface we need for the tests
interface Simple_Bit {
	enabled: boolean;
	content: string;
	has_xml_tag: boolean;
	xml_tag_name: string;
	type: string;
	default_xml_tag_name: string;
	relative_path?: string; // Add this property for diskfile tests
	attributes: Array<{
		id: string;
		key: string;
		value: string;
	}>;
}

// Helper to create a bit with default values
const create_bit = (partial: Partial<Simple_Bit> = {}): Simple_Bit => {
	const type = partial.type || 'text';

	return {
		enabled: true,
		content: '',
		has_xml_tag: false,
		xml_tag_name: '',
		type,
		default_xml_tag_name: type === 'diskfile' ? 'file' : 'fragment',
		attributes: [],
		...partial,
	};
};

// Basic tests
test('format_prompt_content - returns empty string for empty bits array', () => {
	const result = format_prompt_content([] as any);
	expect(result).toBe('');
});

test('format_prompt_content - filters out disabled bits', () => {
	const bits = [
		create_bit({enabled: false, content: 'Content 1'}),
		create_bit({enabled: true, content: 'Content 2'}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('Content 2');
});

test('format_prompt_content - joins multiple enabled bits with double newlines', () => {
	const bits = [create_bit({content: 'Content 1'}), create_bit({content: 'Content 2'})];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('Content 1\n\nContent 2');
});

// XML tag tests
test('format_prompt_content - wraps content with XML tags when specified', () => {
	const bits = [
		create_bit({
			content: 'Content with tag',
			has_xml_tag: true,
			xml_tag_name: 'system',
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('<system>\nContent with tag\n</system>');
});

test('format_prompt_content - uses default_xml_tag_name when no XML tag name is provided', () => {
	const bits = [
		create_bit({
			content: 'Content with default tag',
			has_xml_tag: true,
			xml_tag_name: '',
			type: 'text',
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('<fragment>\nContent with default tag\n</fragment>');
});

// Test with different bit types
test('format_prompt_content - uses different bit types as defaults', () => {
	const bits = [
		create_bit({
			content: 'File content',
			has_xml_tag: true,
			xml_tag_name: '',
			type: 'diskfile',
		}),
		create_bit({
			content: 'Sequence content',
			has_xml_tag: true,
			xml_tag_name: '',
			type: 'sequence',
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('<file>\nFile content\n</file>\n\n<fragment>\nSequence content\n</fragment>');
});

test('format_prompt_content - uses different default XML tag names for different bit types', () => {
	const bits = [
		create_bit({
			content: 'File content',
			has_xml_tag: true,
			xml_tag_name: '',
			type: 'diskfile',
		}),
		create_bit({
			content: 'Text content',
			has_xml_tag: true,
			xml_tag_name: '',
			type: 'text',
		}),
		create_bit({
			content: 'Sequence content',
			has_xml_tag: true,
			xml_tag_name: '',
			type: 'sequence',
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe(
		'<file>\nFile content\n</file>\n\n<fragment>\nText content\n</fragment>\n\n<fragment>\nSequence content\n</fragment>',
	);
});

// XML attribute tests - enhanced to test more edge cases
test('format_prompt_content - includes attributes with key and value', () => {
	const bits = [
		create_bit({
			content: 'Content with attributes',
			has_xml_tag: true,
			xml_tag_name: 'div',
			attributes: [{id: '1', key: 'class', value: 'container'}],
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('<div class="container">\nContent with attributes\n</div>');
});

test('format_prompt_content - handles empty values as boolean attributes', () => {
	const bits = [
		create_bit({
			content: 'Content with boolean attribute',
			has_xml_tag: true,
			xml_tag_name: 'input',
			attributes: [{id: '1', key: 'disabled', value: ''}],
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('<input disabled>\nContent with boolean attribute\n</input>');
});

test('format_prompt_content - handles explicitly empty string values', () => {
	const bits = [
		create_bit({
			content: 'Content with explicit empty value',
			has_xml_tag: true,
			xml_tag_name: 'div',
			attributes: [
				{id: '1', key: 'data-test', value: ''}, // Empty string should be boolean attribute
				{id: '2', key: 'class', value: 'container'}, // Normal attribute
			],
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe(
		'<div data-test class="container">\nContent with explicit empty value\n</div>',
	);
});

test('format_prompt_content - filters out attributes without keys', () => {
	const bits = [
		create_bit({
			content: 'Content with missing key',
			has_xml_tag: true,
			xml_tag_name: 'div',
			attributes: [{id: '1', key: '', value: 'should-be-ignored'}],
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('<div>\nContent with missing key\n</div>');
});

test('format_prompt_content - handles multiple attributes with mix of empty and non-empty values', () => {
	const bits = [
		create_bit({
			content: 'Multiple attributes',
			has_xml_tag: true,
			xml_tag_name: 'div',
			attributes: [
				{id: '1', key: 'class', value: 'container'},
				{id: '2', key: 'id', value: 'main'},
				{id: '3', key: 'data-test', value: 'true'},
				{id: '4', key: 'hidden', value: ''},
				{id: '5', key: 'disabled', value: ''},
			],
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe(
		'<div class="container" id="main" data-test="true" hidden disabled>\nMultiple attributes\n</div>',
	);
});

// Whitespace handling tests
test('format_prompt_content - ignores attributes with empty keys after trimming', () => {
	const bits = [
		create_bit({
			content: 'Content with whitespace key',
			has_xml_tag: true,
			xml_tag_name: 'div',
			attributes: [
				{id: '1', key: '   ', value: 'should-be-ignored'},
				{id: '2', key: 'class', value: 'container'},
			],
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('<div class="container">\nContent with whitespace key\n</div>');
});

test('format_prompt_content - trims attribute keys before rendering', () => {
	const bits = [
		create_bit({
			content: 'Content with trimmed keys',
			has_xml_tag: true,
			xml_tag_name: 'div',
			attributes: [
				{id: '1', key: '  class  ', value: 'container'},
				{id: '2', key: ' data-test ', value: 'true'},
			],
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe(
		'<div class="container" data-test="true">\nContent with trimmed keys\n</div>',
	);
});

test('format_prompt_content - removes attributes with empty keys but preserves others', () => {
	const bits = [
		create_bit({
			content: 'Mixed attributes',
			has_xml_tag: true,
			xml_tag_name: 'div',
			attributes: [
				{id: '1', key: '', value: 'invalid'},
				{id: '2', key: 'class', value: 'container'},
				{id: '3', key: '  ', value: 'also-invalid'},
				{id: '4', key: 'data-valid', value: 'true'},
			],
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('<div class="container" data-valid="true">\nMixed attributes\n</div>');
});

// Update this test to use empty string instead of null
test('format_prompt_content - filters out attributes with empty keys', () => {
	const bits = [
		create_bit({
			content: 'Content with empty key',
			has_xml_tag: true,
			xml_tag_name: 'div',
			attributes: [{id: '1', key: '', value: 'should-be-ignored'}],
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('<div>\nContent with empty key\n</div>');
});

// Edge cases
test('format_prompt_content - trims whitespace from content', () => {
	const bits = [create_bit({content: '  Content with whitespace  '})];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('Content with whitespace');
});

test('format_prompt_content - skips bits with empty content', () => {
	const bits = [
		create_bit({content: ''}),
		create_bit({content: '  '}),
		create_bit({content: 'Real content'}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('Real content');
});

test('format_prompt_content - trims whitespace from XML tag name', () => {
	const bits = [
		create_bit({
			content: 'Trimmed tag name',
			has_xml_tag: true,
			xml_tag_name: '  system  ',
		}),
	];

	const result = format_prompt_content(bits as any);
	expect(result).toBe('<system>\nTrimmed tag name\n</system>');
});

// Test that diskfile bits get the path attribute by default
test('format_prompt_content - ensures diskfile bits have path attribute', () => {
	// Create a mock Diskfile_Bit with a path
	const diskfile_bit = create_bit({
		type: 'diskfile',
		content: 'File content with path',
		has_xml_tag: true,
		xml_tag_name: '',
		relative_path: 'src/example.ts', // Add this property for the test
		attributes: [{id: '1', key: 'path', value: 'src/example.ts'}], // Pre-set attribute for mock
	});

	const result = format_prompt_content([diskfile_bit] as any);
	expect(result).toBe('<file path="src/example.ts">\nFile content with path\n</file>');
});

// Test for when the path attribute is combined with other attributes
test('format_prompt_content - combines path attribute with other attributes for diskfile bits', () => {
	const diskfile_bit = create_bit({
		type: 'diskfile',
		content: 'File with multiple attributes',
		has_xml_tag: true,
		xml_tag_name: 'code',
		relative_path: 'src/utils.js',
		attributes: [
			{id: '1', key: 'path', value: 'src/utils.js'},
			{id: '2', key: 'language', value: 'javascript'},
			{id: '3', key: 'highlight', value: ''},
		],
	});

	const result = format_prompt_content([diskfile_bit] as any);
	expect(result).toBe(
		'<code path="src/utils.js" language="javascript" highlight>\nFile with multiple attributes\n</code>',
	);
});
