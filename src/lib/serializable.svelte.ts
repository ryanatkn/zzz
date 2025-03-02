// serializable.svelte.ts

import {z} from 'zod';
import {DEV} from 'esm-env';

import {zod_get_schema_keys} from '$lib/zod_helpers.js';

// TODO maybe rename to `Json_Serializable` to be more explicit? Or `Snapshottable`?
export abstract class Serializable<T_Json, T_Schema extends z.ZodType> {
	readonly schema: T_Schema;
	readonly schema_keys: Array<string> = $derived.by(() => zod_get_schema_keys(this.schema));

	readonly json: T_Json = $derived.by(() => this.to_json());
	readonly json_serialized: string = $derived(JSON.stringify(this.json));
	readonly json_parsed: z.SafeParseReturnType<z.output<T_Schema>, z.output<T_Schema>> = $derived.by(
		() => this.schema.safeParse(this.json),
	);

	// Add an optional zzz property that will be available to all subclasses
	readonly zzz?: any;

	constructor(schema: T_Schema, zzz?: any) {
		this.schema = schema;
		this.zzz = zzz;
	}

	/**
	 * Default implementation that introspects the Zod schema to determine
	 * which properties to include in the serialized object.
	 * Override this method for custom serialization behavior.
	 */
	to_json(): T_Json {
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

		return result as T_Json;
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
	toJSON(): T_Json {
		return this.json;
	}

	/**
	 * Generic clone method that works for any subclass.
	 * Returns the same type as 'this' to preserve the exact subclass type.
	 */
	clone(): this {
		// Get the constructor of this instance
		const constructor = this.constructor as new (options: {
			zzz?: any;
			json?: z.input<T_Schema>;
		}) => this;

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
