// cell.svelte.ts

import {z} from 'zod';
import {DEV} from 'esm-env';

import {zod_get_schema_keys} from '$lib/zod_helpers.js';
import type {Zzz} from '$lib/zzz.svelte.js';

// Metadata properties for Zod schemas.
// TODO better way to do this? Forces use of the helpers `cell_class` and `cell_array`
export const ZOD_CELL_CLASS_NAME = 'zzz_cell_class_name';
export const ZOD_ELEMENT_CLASS_NAME = 'zzz_element_class_name';

// TODO refactor
interface Schema_Info {
	type?: string;
	is_array?: boolean;
	class_name?: string;
	element_class?: string;
}

// Base options type that all cells will extend
export interface Cell_Options<T_Schema extends z.ZodType, T_Zzz extends Zzz = Zzz> {
	zzz: T_Zzz;
	json?: z.input<T_Schema>;
}

/**
 * Attaches class name metadata to a Zod schema for cell instantiation.
 * This allows the cell system to know which class to instantiate for a given schema.
 *
 * @param schema The Zod schema to annotate
 * @param className The name of the class to instantiate for this schema
 * @returns The original schema with metadata attached
 */
export function cell_class<T extends z.ZodTypeAny>(schema: T, className: string): T {
	// Instead of using transform which changes the type, just attach metadata
	(schema as any)[ZOD_CELL_CLASS_NAME] = className;
	return schema;
}

/**
 * Attaches element class name metadata to an array schema for cell array instantiation.
 * This allows the cell system to know which class to instantiate for each element in the array.
 *
 * @param schema The array Zod schema to annotate (or ZodDefault containing an array)
 * @param className The name of the class to instantiate for each element
 * @returns The original schema with metadata attached
 */
export function cell_array<T extends z.ZodTypeAny>(schema: T, className: string): T {
	// Use type casting to access the inner ZodArray if this is a ZodDefault
	// This safely handles both direct ZodArrays and ZodDefault<ZodArray>
	const arraySchema =
		schema instanceof z.ZodDefault
			? (schema._def.innerType as z.ZodArray<any>)
			: (schema as unknown as z.ZodArray<any>);

	// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
	if (!arraySchema._def) {
		console.warn('cell_array: Schema is not a ZodArray or ZodDefault<ZodArray>');
		return schema;
	}

	// Add the element_class property to the array schema
	(arraySchema._def as any)[ZOD_ELEMENT_CLASS_NAME] = className;
	return schema;
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
	 * Initialize the instance with options.json data if provided.
	 * Should be called by subclasses at the end of their constructor.
	 */
	protected init(): void {
		if (this.options.json !== undefined) {
			this.set_json(this.options.json);
		} else {
			this.apply_defaults();
		}
	}

	/**
	 * Apply schema defaults safely for properties that don't already have values.
	 */
	protected apply_defaults(): void {
		try {
			// Get the default values from the schema
			const defaults = this.schema.parse(undefined);

			// Only apply defaults for properties that don't exist yet
			for (const key of this.schema_keys) {
				if (!(key in this) || (this as any)[key] === undefined) {
					try {
						(this as any)[key] = defaults[key];
					} catch (e) {
						// Skip properties that can't be assigned (e.g., private members)
						console.warn(
							`Couldn't apply default for property ${key} in ${this.constructor.name}`,
							e,
						);
					}
				}
			}
		} catch (error) {
			console.error(`Error applying defaults for ${this.constructor.name}:`, error);
		}
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

	// TODO cache, derived?
	/**
	 * Extract schema information for a field
	 */
	#get_schema_info(key: string): Schema_Info | null {
		const field_schema = this.#get_field_schema(key);
		if (!field_schema) return null;

		const def = (field_schema as any)._def;
		if (!def) return null;

		const result: Schema_Info = {
			type: def.typeName,
		};

		// Check if it's an array
		if (def.typeName === 'ZodArray') {
			result.is_array = true;

			// Look for element class metadata
			if (def[ZOD_ELEMENT_CLASS_NAME]) {
				result.element_class = def[ZOD_ELEMENT_CLASS_NAME];
			}

			// Also look at the inner type
			const element_type = def.type;
			if (element_type?.[ZOD_CELL_CLASS_NAME]) {
				result.element_class = element_type[ZOD_CELL_CLASS_NAME];
			}
		}
		// Check for class metadata on the field itself
		else if ((field_schema as any)[ZOD_CELL_CLASS_NAME]) {
			result.class_name = (field_schema as any)[ZOD_CELL_CLASS_NAME];
		}

		return result;
	}

	/**
	 * Get the Zod schema for a specific field
	 */
	#get_field_schema(key: string): z.ZodTypeAny | undefined {
		// Access the schema's shape if it's an object schema
		const schema_obj = this.schema as unknown as {shape?: Record<string, z.ZodTypeAny>};
		return schema_obj.shape?.[key];
	}

	// Fix the instantiate_class method to handle undefined
	#instantiate_class<T>(class_name: string | undefined, json: unknown): T | unknown {
		if (!class_name) {
			return json;
		}

		const instance = this.zzz.registry.instantiate<T>(class_name, json);
		return instance !== null ? instance : json;
	}

	/**
	 * For Svelte's $snapshot
	 */
	toJSON(): z.output<T_Schema> {
		return this.json;
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
}
