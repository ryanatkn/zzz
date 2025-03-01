// serializable.svelte.ts

import type {z} from 'zod';

export interface Serializable_Options<T_Json> {
	json?: Partial<T_Json>;
}

/**
 * Interface to describe the expected static methods on Serializable classes
 */
export interface Serializable_Constructor<T extends Serializable<any, any>, J = any> {
	new (options?: Serializable_Options<J>): T;
	create_default: () => T;
	from_json: (json: Partial<J>) => T;
}

export abstract class Serializable<T_Json, T_Schema extends z.ZodType> {
	json: T_Json = $derived.by(() => this.to_json());
	json_serialized: string = $derived(JSON.stringify(this.json));

	protected abstract schema: T_Schema;

	constructor(options?: Serializable_Options<T_Json>) {
		if (options?.json) {
			this.set_json(options.json);
		}
	}

	// Core serialization methods
	abstract to_json(): T_Json;
	abstract set_json(value: z.input<T_Schema>): void;

	toJSON(): T_Json {
		return this.json;
	}

	validate(): z.SafeParseReturnType<z.output<T_Schema>, z.output<T_Schema>> {
		return this.schema.safeParse(this.json);
	}

	clone(): this {
		const clone = new (this.constructor as new () => this)();
		clone.set_json(this.to_json() as z.input<T_Schema>);
		return clone;
	}
}
