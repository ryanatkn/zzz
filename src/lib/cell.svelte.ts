import {z} from 'zod';
import {format} from 'date-fns';

import {get_field_schema, zod_get_schema_keys, type Uuid, type Datetime} from '$lib/zod_helpers.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {
	get_schema_class_info,
	type Schema_Class_Info,
	type Cell_Value_Parser,
} from '$lib/cell_helpers.js';
import type {Schema_Keys, Cell_Json} from '$lib/cell_types.js';

// TODO needs refinement
// Constants for date formatting
export const FILE_SHORT_DATE_FORMAT = 'MMM d, p';
export const FILE_DATE_FORMAT = 'MMM d, yyyy h:mm:ss a';
export const FILE_TIME_FORMAT = 'HH:mm:ss';

// Base options type that all cells will extend
export interface Cell_Options<T_Schema extends z.ZodType> {
	zzz: Zzz;
	json?: z.input<T_Schema>;
}

export abstract class Cell<T_Schema extends z.ZodType = z.ZodType> implements Cell_Json {
	// Base properties from Cell_Json
	id: Uuid = $state()!;
	created: Datetime = $state()!;
	updated: Datetime | null = $state()!;

	readonly schema: T_Schema; // TODO think about making this $state - dynamic schemas? idk, not yet

	readonly schema_keys: Array<Schema_Keys<T_Schema>> = $derived.by(() =>
		zod_get_schema_keys(this.schema),
	);
	readonly field_schemas: Map<Schema_Keys<T_Schema>, z.ZodType> = $derived.by(
		() => new Map(this.schema_keys.map((key) => [key, get_field_schema(this.schema, key)])),
	);
	readonly field_schema_info: Map<Schema_Keys<T_Schema>, Schema_Class_Info | null> = $derived(
		new Map(
			this.schema_keys.map((key) => {
				const field_schema = this.field_schemas.get(key);
				if (!field_schema) {
					return [key, null];
				}
				return [key, get_schema_class_info(field_schema)];
			}),
		),
	);

	readonly json: z.output<T_Schema> = $derived(this.to_json());
	readonly json_serialized: string = $derived(JSON.stringify(this.json));
	readonly json_parsed: z.SafeParseReturnType<z.output<T_Schema>, z.output<T_Schema>> = $derived.by(
		() => this.schema.safeParse(this.json),
	);

	// Make zzz required
	readonly zzz: Zzz;

	// Store options for use during initialization
	protected readonly options: Cell_Options<T_Schema>;

	// TODO most of the overrides for this should be replaceable with schema introspection I think
	/**
	 * Type-safe parsers for custom field decoding.
	 * Override in subclasses to handle special field types.
	 *
	 * This uses Cell_Value_Parser which includes typing for
	 * the base cell properties (id, created, updated).
	 */
	protected parsers: Cell_Value_Parser<T_Schema> = {};

	created_date: Date = $derived(new Date(this.created));
	created_formatted_short_date: string = $derived(
		format(this.created_date, FILE_SHORT_DATE_FORMAT),
	);
	created_formatted_date: string = $derived(format(this.created_date, FILE_DATE_FORMAT));
	created_formatted_time: string = $derived(format(this.created_date, FILE_TIME_FORMAT));

	updated_date: Date | null = $derived(this.updated ? new Date(this.updated) : null);
	updated_formatted_short_date: string | null = $derived(
		this.updated_date ? format(this.updated_date, FILE_SHORT_DATE_FORMAT) : null,
	);
	updated_formatted_date: string | null = $derived(
		this.updated_date ? format(this.updated_date, FILE_DATE_FORMAT) : null,
	);
	updated_formatted_time: string | null = $derived(
		this.updated_date ? format(this.updated_date, FILE_TIME_FORMAT) : null,
	);

	constructor(schema: T_Schema, options: Cell_Options<T_Schema>) {
		this.schema = schema;
		this.zzz = options.zzz;
		this.options = options;

		// Don't auto-initialize here - wait for subclass to call init()
	}

	/**
	 * Initialize the instance with `options.json` data if provided.
	 * Should be called by subclasses at the end of their constructor
	 * or elsewhere before using the instance.
	 */
	protected init(): void {
		this.set_json(this.options.json); // `set_json` parses with the schema, so this may be `undefined` and it's fine
	}

	/**
	 * For Svelte's $snapshot.
	 */
	toJSON(): z.output<T_Schema> {
		return this.json;
	}

	to_json(): z.output<T_Schema> {
		const result: z.output<T_Schema> = {};

		for (const key of this.schema_keys) {
			if (key in this) {
				result[key] = this.encode_property(this[key], key);
			} else {
				console.error(`Property ${key} not found on instance of ${this.constructor.name}`);
			}
		}

		return result;
	}

	/**
	 * Apply JSON data to this instance.
	 */
	set_json(value?: z.input<T_Schema>): void {
		try {
			// Use empty object if value is undefined to ensure schema processes defaults
			const input = value === undefined ? {} : value;

			// Parse input with schema - this will apply schema defaults for missing fields
			const parsed = this.schema.parse(input);

			// Process each schema key
			for (const key of this.schema_keys) {
				// Get the value from parsed data (might be schema default)
				const parsed_value = parsed[key];

				// Process this schema property
				this.assign_property(key, parsed_value);
			}
		} catch (error) {
			console.error(`Error setting JSON for ${this.constructor.name}:`, error);
			throw error; // Re-throw so tests that expect errors will pass
		}
	}

	/**
	 * Encode a value during serialization. Can be overridden for custom encoding logic.
	 * Defaults to Svelte's `$state.snapshot`,
	 * which handles most cases and uses `toJSON` when available,
	 * so overriding `to_json` is sufficient for most cases before overriding `encode`.
	 */
	encode_property(value: unknown, _key: string): unknown {
		return $state.snapshot(value);
	}

	/**
	 * Decode a value based on its schema type information.
	 * This handles instantiating classes, transforming arrays, and special types.
	 */
	decode_property<K extends Schema_Keys<T_Schema>>(value: unknown, key: K): this[K] {
		const schema_info = this.field_schema_info.get(key);
		if (!schema_info) return value as this[K];

		// Handle arrays of cells
		if (schema_info.is_array && Array.isArray(value)) {
			if (schema_info.element_class) {
				return value.map((item) => {
					const instance = this.#instantiate_class(schema_info.element_class, item);
					// Return the item if instantiation returns null
					return instance !== null ? instance : item;
				}) as this[K];
			}
			return value as this[K];
		}

		// Handle individual cell
		if (schema_info.class_name && value && typeof value === 'object') {
			const instance = this.#instantiate_class(schema_info.class_name, value);
			// Return the original value if instantiation returns null
			return (instance !== null ? instance : value) as this[K];
		}

		// Handle special types
		if (schema_info.type === 'ZodMap' && Array.isArray(value)) {
			return new Map(value) as this[K];
		}
		if (schema_info.type === 'ZodSet' && Array.isArray(value)) {
			return new Set(value) as this[K];
		}
		if (schema_info.type === 'ZodBranded' && value !== null && value !== undefined) {
			try {
				// Use the schema directly to parse branded types
				const field_schema = this.field_schemas.get(key);
				return (field_schema?.parse(value) ?? value) as this[K];
			} catch (e) {
				console.error(`Failed to parse branded type for ${key}:`, e);
				return value as this[K];
			}
		}

		return value as this[K];
	}

	/**
	 * Generic clone method that works for any subclass.
	 */
	clone(): this {
		const constructor = this.constructor as new (options: Cell_Options<T_Schema>) => this;

		try {
			// TODO @many maybe optionally forward additional rest options?
			return new constructor({
				zzz: this.zzz,
				json: structuredClone(this.json),
			});
		} catch (error) {
			console.error(`Failed to clone instance of ${constructor.name}:`, error);
			throw new Error(`Failed to clone: ${error instanceof Error ? error.message : String(error)}`);
		}
	}

	/**
	 * Process a single schema property during JSON deserialization.
	 * This method handles the flow for how schema properties map to instance properties.
	 */
	protected assign_property(key: Schema_Keys<T_Schema>, value: unknown): void {
		// 1. Check if we have a parser for this key
		const has_parser = key in this.parsers;
		const has_property = key in this;

		// 2. If we don't have a property or parser, log an error and bail
		if (!has_property && !has_parser) {
			console.error(
				`Schema key "${key}" in ${this.constructor.name} has no matching property or parser. ` +
					`Consider adding the property or a parser.`,
			);
			return;
		}

		// 3. Try to use the parser if available
		if (has_parser) {
			const parser = this.parsers[key];
			if (parser) {
				const parsed = parser(value);

				// 3a. If parser returns a defined value AND we have a property, assign it
				if (parsed !== undefined && has_property) {
					this[key] = parsed;
					return;
				}

				// 3b. If parser returns undefined but we have a property,
				// fall through to standard decoding

				// 3c. If we don't have a property but have a parser,
				// the parser is expected to handle the virtual property
				if (!has_property) {
					return;
				}
			}
		}

		// 4. Use standard decoding if we have a property and value
		if (has_property && value !== undefined) {
			const decoded = this.decode_property(value, key);
			this[key] = decoded;
		}
	}

	/**
	 * Instantiate a cell class using the registry.
	 */
	#instantiate_class(class_name: string | undefined, json: unknown): unknown {
		if (!class_name) {
			console.error('No class name provided for instantiation');
			return null;
		}

		const instance = this.zzz.registry.instantiate(class_name, json);
		if (!instance) console.error('No class name provided for instantiation');
		return instance;
	}
}
