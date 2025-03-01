// serializable.svelte.ts

import {z} from 'zod';
import {DEV} from 'esm-env';

import {zod_get_schema_keys} from '$lib/zod_helpers.js';

export interface Serializable_Constructor<T_Class extends Serializable<any, any>, T_Json = any> {
	from_json: (json?: T_Json) => T_Class;
}

// TODO maybe rename to `Json_Serializable` to be more explicit? Or `Snapshottable`?
export abstract class Serializable<T_Json, T_Schema extends z.ZodType> {
	readonly schema: T_Schema;
	readonly schema_keys: Array<string> = $derived.by(() => zod_get_schema_keys(this.schema));

	readonly json: T_Json = $derived.by(() => this.to_json());
	readonly json_serialized: string = $derived(JSON.stringify(this.json));
	readonly json_parsed: z.SafeParseReturnType<z.output<T_Schema>, z.output<T_Schema>> = $derived.by(
		() => this.schema.safeParse(this.json),
	);

	constructor(schema: T_Schema) {
		this.schema = schema;
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

	toJSON(): T_Json {
		return this.json;
	}

	clone(): this {
		const constructor = this.constructor as typeof Serializable & {from_json: (json: any) => any};

		if (typeof constructor.from_json !== 'function') {
			throw new Error(`${constructor.name} must implement static from_json method for cloning`);
		}

		return constructor.from_json(this.to_json());
	}

	/**
	 * Type check helper - does nothing at runtime
	 * but enforces static interface compliance with `Serializable_Constructor`
	 */
	protected static check_subclass<
		T_Class extends Serializable<T_Json, T_Schema>,
		T_Json,
		T_Schema extends z.ZodType,
	>(_c: Serializable_Constructor<T_Class, T_Json>): void {
		// typechecking
	}
}
