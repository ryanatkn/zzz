// @vitest-environment jsdom

import {test, expect, vi, beforeEach} from 'vitest';
import {z} from 'zod';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Cell_Json} from '$lib/cell_types.js';
import {Datetime_Now, get_datetime_now, create_uuid, Uuid_With_Default} from '$lib/zod_helpers.js';
import {HANDLED} from '$lib/cell_helpers.js';
import {Zzz} from '$lib/zzz.svelte.js';
import {monkeypatch_zzz_for_tests} from '$lib/test_helpers.js';

// Constants for testing
const TEST_ID = create_uuid();
const TEST_DATETIME = get_datetime_now();

// Test suite variables
let zzz: Zzz;

beforeEach(() => {
	// Create a real Zzz instance for each test
	zzz = monkeypatch_zzz_for_tests(new Zzz());
	vi.clearAllMocks();
});

test('Cell allows schema keys with no properties if a decoder is provided', () => {
	const Virtual_Property_Schema = Cell_Json.extend({
		real_prop: z.string().default(''),
		virtual_prop: z.number().default(42), // Won't exist on class
	});

	class Virtual_Property_Cell extends Cell<typeof Virtual_Property_Schema> {
		real_prop: string = $state()!;
		// No 'virtual_prop', will be handled by decoder

		captured_value = 0; // For verification

		constructor(options: Cell_Options<typeof Virtual_Property_Schema>) {
			super(Virtual_Property_Schema, options);

			this.decoders = {
				virtual_prop: (value) => {
					this.captured_value = typeof value === 'number' ? value : 0;
					return HANDLED;
				},
			};

			this.init();
		}
	}

	const cell = new Virtual_Property_Cell({
		zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATETIME,
			virtual_prop: 99,
		},
	});

	expect(cell.captured_value).toBe(99);
});

test('Cell supports virtual properties with custom handling', () => {
	const Virtual_Handler_Schema = z.object({
		id: Uuid_With_Default,
		created: Datetime_Now,
		updated: z.string().nullable().default(null),
		visible_prop: z.string(),
		hidden_prop: z.number().default(0),
	});

	class Virtual_Handler_Cell extends Cell<typeof Virtual_Handler_Schema> {
		visible_prop: string = $state()!;
		// No hidden_prop property

		processed_value = 0;

		constructor(options: Cell_Options<typeof Virtual_Handler_Schema>) {
			super(Virtual_Handler_Schema, options);

			this.decoders = {
				hidden_prop: (value) => {
					if (typeof value === 'number') {
						this.processed_value = value * 2;
					}
					return HANDLED; // Must return HANDLED for virtual properties
				},
			};

			this.init();
		}
	}

	const cell = new Virtual_Handler_Cell({
		zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATETIME,
			visible_prop: 'visible',
			hidden_prop: 42,
		},
	});

	expect(cell.visible_prop).toBe('visible');
	expect('hidden_prop' in cell).toBe(false);
	expect(cell.processed_value).toBe(84); // 42 * 2
});

test('Cell handles sentinel values with proper precedence', () => {
	const Sentinel_Schema = Cell_Json.extend({
		handled_field: z.string().default(''),
		default_field: z.number().default(0),
		normal_field: z.boolean().default(false),
	});

	class Sentinel_Test_Cell extends Cell<typeof Sentinel_Schema> {
		handled_field: string = $state('initial_value');
		default_field: number = $state(-1);
		normal_field: boolean = $state()!;

		decoder_calls: Array<string> = [];

		constructor(options: Cell_Options<typeof Sentinel_Schema>) {
			super(Sentinel_Schema, options);

			this.decoders = {
				handled_field: (_value) => {
					this.decoder_calls.push('handled_field_called');
					// Short-circuit with HANDLED
					return HANDLED;
				},
				default_field: (_value) => {
					this.decoder_calls.push('default_field_called');
					// Fall through to default decoding
					return undefined;
				},
				normal_field: (_value) => {
					this.decoder_calls.push('normal_field_called');
					// Override with custom value
					return true;
				},
			};

			this.init();
		}
	}

	const cell = new Sentinel_Test_Cell({
		zzz,
		json: {
			id: TEST_ID,
			created: TEST_DATETIME,
			handled_field: 'input_value',
			default_field: 42,
			normal_field: false,
		},
	});

	expect(cell.decoder_calls).toContain('handled_field_called');
	expect(cell.decoder_calls).toContain('default_field_called');
	expect(cell.decoder_calls).toContain('normal_field_called');

	expect(cell.handled_field).toBe('initial_value');
	expect(cell.default_field).toBe(42);
	expect(cell.normal_field).toBe(true);
});

test('Cell parser defaults take precedence over schema defaults', () => {
	const Default_Precedence_Schema = z.object({
		id: z.string().default('schema_default_id'),
		created: Datetime_Now,
		updated: z.string().nullable().default(null),
		text: z.string().default('schema_default_text'),
	});

	class Default_Precedence_Cell extends Cell<typeof Default_Precedence_Schema> {
		text: string = $state()!;

		constructor(options: Cell_Options<typeof Default_Precedence_Schema>) {
			super(Default_Precedence_Schema, options);

			this.decoders = {
				id: (value) => {
					if (typeof value === 'string' && value !== 'schema_default_id') {
						return value;
					}
					return 'parser_default_id';
				},
				// No decoder for text - schema default should be used
			};

			this.init();
		}
	}

	const cell = new Default_Precedence_Cell({
		zzz,
		json: {},
	});

	expect(cell.id).toBe('parser_default_id');
	expect(cell.text).toBe('schema_default_text');
});
