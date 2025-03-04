// cell.svelte.ts

import {z} from 'zod';
import {DEV} from 'esm-env';

import {zod_get_schema_keys} from '$lib/zod_helpers.js';
import type {Zzz} from '$lib/zzz.svelte.js';

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

	// Property to store class-specific metadata for deserialization
	static readonly schema_id?: string;

	constructor(schema: T_Schema, options: Cell_Options<T_Schema, T_Zzz>) {
		this.schema = schema;
		this.zzz = options.zzz;
		this.options = options;

		// We do NOT automatically call this.init() here due to Svelte's initialization order
		// Subclasses must call this.init() at the end of their constructor
	}

	/**
	 * Initialize the instance with options.json data if provided.
	 * Must be called by subclasses at the end of their constructor.
	 */
	protected init(): void {
		this.set_json(this.schema.parse(this.options.json));
	}

	/**
	 * Default implementation that introspects the Zod schema to determine
	 * which properties to include in the serialized object.
	 * Override this method for custom serialization behavior.
	 */
	to_json(): z.output<T_Schema> {
		const result: Record<string, any> = {};

		for (const key of this.schema_keys) {
			// Only include properties that exist on this instance
			if (key in this) {
				// Use $state.snapshot for all values to handle Svelte 5 reactivity
				result[key] = this.encode((this as any)[key], key);
			} else {
				if (DEV) console.error(`Property ${key} not found on instance of ${this.constructor.name}`);
			}
		}

		return result as z.output<T_Schema>;
	}

	/**
	 * Encode a value during serialization. Can be overridden for custom encoding logic.
	 * @param value The value to encode
	 * @param key The property key
	 * @returns The encoded value
	 */
	encode(value: unknown, _key: string): unknown {
		// TODO inspect the schema to automate encoding behavior
		return $state.snapshot(value);
	}

	/**
	 * Override for custom behavior
	 */
	set_json(value?: z.input<T_Schema>): void {
		const parsed = this.schema.parse(value);
		for (const key in parsed) {
			(this as any)[key] = this.decode(parsed[key], key, parsed, this.schema);
		}
	}

	/**
	 * Decode values during deserialization, handling nested cells and complex types
	 * @param value The value to decode
	 * @param key The property key
	 * @param parsed The complete parsed object
	 * @param schema The schema for validation
	 * @returns The decoded value
	 */
	decode(value: unknown, key: string, _parsed: Record<string, unknown>, schema: T_Schema): unknown {
		// Check if we have type information in the schema with safer access
		// Use type assertion since we know the internal structure of Zod schemas
		const zod_obj = schema as unknown as {shape?: Record<string, any>};
		const field_schema = zod_obj.shape?.[key];

		// Handle arrays of cells
		if (field_schema?._def?.typeName === 'ZodArray') {
			const element_schema = field_schema._def.type;
			// Use class_name attribute instead of schema_id
			if (element_schema?.class_name && Array.isArray(value)) {
				return value.map((item) => this.zzz.registry.decode(item, element_schema.class_name));
			}
		}
		// Handle single cell objects
		else if (field_schema?.class_name) {
			return this.zzz.registry.decode(value, field_schema.class_name);
		}
		// Handle Maps
		else if (field_schema?._def?.typeName === 'ZodMap' && Array.isArray(value)) {
			return new Map(value as Array<[any, any]>);
		}
		// Handle Sets
		else if (field_schema?._def?.typeName === 'ZodSet' && Array.isArray(value)) {
			return new Set(value);
		}
		// Handle branded types
		else if (
			field_schema?._def?.typeName === 'ZodBranded' &&
			value !== null &&
			value !== undefined
		) {
			return field_schema.parse(value);
		}

		// Default behavior
		return value;
	}

	/**
	 * For Svelte's $snapshot
	 */
	toJSON(): z.output<T_Schema> {
		return this.json;
	}

	/**
	 * Generic clone method that works for any subclass.
	 * Returns the same type as 'this' to preserve the exact subclass type.
	 */
	clone(): this {
		// Get the constructor of this instance
		const constructor = this.constructor as new (options: Cell_Options<T_Schema, T_Zzz>) => this;

		try {
			// Create a new instance with the copied JSON and the same zzz reference
			return new constructor({
				zzz: this.zzz,
				json: structuredClone(this.json),
			});
		} catch (error) {
			console.error(`Failed to clone instance of ${constructor.name}:`, error);
			throw new Error(`Failed to clone: ${error instanceof Error ? error.message : String(error)}`);
		}
	}
}
