import {z} from 'zod';

import {get_field_schema, zod_get_schema_keys} from '$lib/zod_helpers.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {
	get_schema_class_info,
	type Schema_Class_Info,
	type Value_Parser,
} from '$lib/cell_helpers.js';

// Base options type that all cells will extend
export interface Cell_Options<T_Schema extends z.ZodType> {
	zzz: Zzz;
	json?: z.input<T_Schema>;
}

// TODO maybe rename to `Json_Cell` to be more explicit? Or `Snapshottable`?
export abstract class Cell<T_Schema extends z.ZodType = z.ZodType> {
	readonly schema: T_Schema; // TODO think about making this $state - dynamic schemas? idk, not yet

	readonly schema_keys: Array<string> = $derived.by(() => zod_get_schema_keys(this.schema));
	readonly field_schemas: Map<string, z.ZodType> = $derived.by(
		() => new Map(this.schema_keys.map((key) => [key, get_field_schema(this.schema, key)])),
	);
	readonly field_schema_info: Map<string, Schema_Class_Info | null> = $derived(
		new Map(
			this.schema_keys.map((key) => {
				const field_schema = this.field_schemas.get(key);
				if (!field_schema) {
					return [key, null];
				}
				return [key, get_schema_class_info(field_schema)] as const;
			}),
		),
	);

	readonly json: z.output<T_Schema> = $derived.by(() => this.to_json());
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
	 */
	protected parsers: Value_Parser<T_Schema> = {};

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
		const result: Record<string, any> = {};

		for (const key of this.schema_keys) {
			if (key in this) {
				result[key] = this.encode((this as any)[key], key);
			} else {
				console.error(`Property ${key} not found on instance of ${this.constructor.name}`);
			}
		}

		return result as z.output<T_Schema>;
	}

	/**
	 * Generic clone method that works for any subclass.
	 */
	clone(): this {
		const constructor = this.constructor as new (options: Cell_Options<T_Schema>) => this;

		try {
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
	 * Encode a value during serialization. Can be overridden for custom encoding logic.
	 * Defaults to Svelte's `$state.snapshot`,
	 * which handles most cases and uses `toJSON` when available,
	 * so overriding `to_json` is sufficient for most cases before overriding `encode`.
	 * @param value The value to encode
	 * @param key The property key
	 * @returns The encoded value
	 */
	encode(value: unknown, _key: string): unknown {
		return $state.snapshot(value);
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

			// Get all schema keys to process them with parsers
			const keys = this.schema_keys;

			for (const key of keys) {
				// Get the value from parsed data (might be schema default)
				const parsed_value = parsed[key];

				// Check if we have a custom parser for this key
				if (key in this.parsers) {
					const parser = this.parsers[key as keyof typeof this.parsers];
					if (parser) {
						// Run parser on the value (could be schema default or from JSON)
						const result = parser(parsed_value);
						if (result !== undefined) {
							// Parser returned a value, use it
							(this as any)[key] = result;
							continue; // Skip standard decoding
						}
					}
				}

				// If parser didn't handle it (returned undefined) or no parser exists,
				// use standard decoding if the value exists
				if (parsed_value !== undefined) {
					(this as any)[key] = this.decode_value_without_parser(parsed_value, key);
				}
			}
		} catch (error) {
			console.error(`Error setting JSON for ${this.constructor.name}:`, error);
			throw error; // Re-throw so tests that expect errors will pass
		}
	}

	/**
	 * Decode a value using schema information to instantiate the right class.
	 * This is the public API that first checks parsers.
	 * @param value The value to decode
	 * @param key The key in the schema where this value belongs
	 */
	decode_value(value: unknown, key: string): unknown {
		// First check if we have a custom parser for this key
		if (key in this.parsers) {
			const parser = this.parsers[key as keyof typeof this.parsers];
			if (parser) {
				const parsed = parser(value);
				// Only return the parsed value if it's not undefined
				if (parsed !== undefined) {
					return parsed;
				}
			}
		}

		// If no custom parser or parser returned undefined, use standard decoding
		return this.decode_value_without_parser(value, key);
	}

	/**
	 * Internal method to decode a value without using parsers.
	 * This is used by the set_json method and as a fallback from decode_value.
	 */
	decode_value_without_parser(value: unknown, key: string): unknown {
		const schema_info = this.field_schema_info.get(key);
		if (!schema_info) return value;

		// Handle arrays of cells
		if (schema_info.is_array && Array.isArray(value)) {
			if (schema_info.element_class) {
				return value.map((item) => {
					const instance = this.#instantiate_class(schema_info.element_class, item);
					// Return the item if instantiation returns null
					return instance !== null ? instance : item;
				});
			}
			return value;
		}

		// Handle individual cell
		if (schema_info.class_name && value && typeof value === 'object') {
			const instance = this.#instantiate_class(schema_info.class_name, value);
			// Return the original value if instantiation returns null
			return instance !== null ? instance : value;
		}

		// Handle special types
		if (schema_info.type === 'ZodMap' && Array.isArray(value)) {
			return new Map(value as Array<[any, any]>);
		}
		if (schema_info.type === 'ZodSet' && Array.isArray(value)) {
			return new Set(value);
		}
		if (schema_info.type === 'ZodBranded' && value !== null && value !== undefined) {
			try {
				// Use the schema directly to parse branded types
				const field_schema = this.field_schemas.get(key);
				return field_schema?.parse(value) ?? value;
			} catch (e) {
				console.error(`Failed to parse branded type for ${key}:`, e);
				return value;
			}
		}

		return value;
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
