// cell.svelte.ts

import {z} from 'zod';
import {DEV} from 'esm-env';

import {get_field_schema, zod_get_schema_keys} from '$lib/zod_helpers.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {
	cell_class,
	cell_array,
	get_schema_class_info,
	ZOD_CELL_CLASS_NAME,
	ZOD_ELEMENT_CLASS_NAME,
} from '$lib/cell_helpers.js';

// Re-export the helpers for backward compatibility
export {cell_class, cell_array, ZOD_CELL_CLASS_NAME, ZOD_ELEMENT_CLASS_NAME};

// Base options type that all cells will extend
export interface Cell_Options<T_Schema extends z.ZodType, T_Zzz extends Zzz = Zzz> {
	zzz: T_Zzz;
	json?: z.input<T_Schema>;
}

// TODO maybe rename to `Json_Cell` to be more explicit? Or `Snapshottable`?
export abstract class Cell<T_Schema extends z.ZodType, T_Zzz extends Zzz = Zzz> {
	readonly schema: T_Schema;
	readonly schema_keys: Array<string> = $derived.by(() => zod_get_schema_keys(this.schema));

	readonly json: z.output<T_Schema> = $derived.by(() => this.to_json());
	readonly json_serialized: string = $derived(JSON.stringify(this.json));
	readonly json_parsed: z.SafeParseReturnType<z.output<T_Schema>, z.output<T_Schema>> = $derived.by(
		() => this.schema.safeParse(this.json),
	);

	// Make zzz required
	readonly zzz: T_Zzz;

	// Store options for use during initialization
	protected readonly options: Cell_Options<T_Schema, T_Zzz>;

	constructor(schema: T_Schema, options: Cell_Options<T_Schema, T_Zzz>) {
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
	 * For Svelte's $snapshot
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
				if (DEV) console.error(`Property ${key} not found on instance of ${this.constructor.name}`);
			}
		}

		return result as z.output<T_Schema>;
	}

	/**
	 * Generic clone method that works for any subclass.
	 */
	clone(): this {
		const constructor = this.constructor as new (options: Cell_Options<T_Schema, T_Zzz>) => this;

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
	 * Apply JSON data to this instance
	 */
	set_json(value?: z.input<T_Schema>): void {
		try {
			const parsed = this.schema.parse(value);
			for (const key in parsed) {
				if (parsed[key] !== undefined) {
					(this as any)[key] = this.decode_value(parsed[key], key);
				}
			}
		} catch (error) {
			console.error(`Error setting JSON for ${this.constructor.name}:`, error);
		}
	}

	/**
	 * Decode a value using schema information to instantiate the right class
	 */
	decode_value(value: unknown, key: string): unknown {
		// Get schema information for this field
		const schema_info = this.#get_schema_info(key);

		if (!schema_info) return value;

		// Handle arrays of cells
		if (schema_info.is_array && Array.isArray(value)) {
			if (schema_info.element_class) {
				return value.map((item) => this.#instantiate_class(schema_info.element_class, item));
			}
			return value;
		}

		// Handle individual cell
		if (schema_info.class_name && value && typeof value === 'object') {
			return this.#instantiate_class(schema_info.class_name, value);
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
				const field_schema = this.#get_field_schema(key);
				return field_schema?.parse(value) ?? value;
			} catch (e) {
				console.error(`Failed to parse branded type for ${key}:`, e);
				return value;
			}
		}

		return value;
	}

	/**
	 * Extract schema information for a field
	 */
	#get_schema_info(key: string): {
		type?: string;
		is_array?: boolean;
		class_name?: string;
		element_class?: string;
	} | null {
		const field_schema = this.#get_field_schema(key);
		// Fix the error by handling the undefined case
		if (!field_schema) {
			return null;
		}
		return get_schema_class_info(field_schema);
	}

	/**
	 * Get the Zod schema for a specific field
	 */
	#get_field_schema(key: string): z.ZodTypeAny | undefined {
		return get_field_schema(this.schema, key);
	}

	// Fix the instantiate_class method to handle undefined
	#instantiate_class<T>(class_name: string | undefined, json: unknown): T | unknown {
		if (!class_name) {
			return json;
		}

		const instance = this.zzz.registry.instantiate<T>(class_name, json);
		return instance !== null ? instance : json;
	}
}
