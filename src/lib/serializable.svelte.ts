// serializable.svelte.ts

import {z} from 'zod';
import {DEV} from 'esm-env';

import {zod_get_schema_keys} from '$lib/zod_helpers.js';

// Base options type that all serializable objects will extend
export interface Serializable_Options<T_Schema extends z.ZodType, T_Zzz = any> {
	zzz: T_Zzz;
	json?: z.input<T_Schema>;
}

// TODO maybe rename to `Json_Serializable` to be more explicit? Or `Snapshottable`?
export abstract class Serializable<T_Schema extends z.ZodType, T_Zzz = any> {
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
	protected readonly options: Serializable_Options<T_Schema, T_Zzz>;

	constructor(schema: T_Schema, options: Serializable_Options<T_Schema, T_Zzz>) {
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
				result[key] = $state.snapshot((this as any)[key]);
			} else {
				if (DEV) console.error(`Property ${key} not found on instance of ${this.constructor.name}`);
			}
		}

		return result as z.output<T_Schema>;
	}

	/**
	 * Override for custom behavior
	 */
	set_json(value?: z.input<T_Schema>): void {
		const parsed = this.schema.parse(value);
		for (const key in parsed) {
			(this as any)[key] = parsed[key];
		}
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
		const constructor = this.constructor as new (
			options: Serializable_Options<T_Schema, T_Zzz>,
		) => this;

		try {
			// Create a new instance with the copied JSON and the same zzz reference
			return new constructor({
				zzz: this.zzz,
				json: structuredClone(this.to_json()),
			});
		} catch (error) {
			console.error(`Failed to clone instance of ${constructor.name}:`, error);
			throw new Error(`Failed to clone: ${error instanceof Error ? error.message : String(error)}`);
		}
	}
}
