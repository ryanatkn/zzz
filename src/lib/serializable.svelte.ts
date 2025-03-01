// serializable.svelte.ts

import type {z} from 'zod';

export interface Serializable_Options<T_Json> {
	json?: Partial<T_Json>;
}

// Interface to describe the expected static methods on Serializable classes
export interface Serializable_Constructor<T extends Serializable<any, any>, J = any> {
	new (options?: Serializable_Options<J>): T;
	create_default: () => T;
	from_json: (json: Partial<J>) => T;
}

export abstract class Serializable<T_Json, T_Schema extends z.ZodType<T_Json>> {
	// Derived properties for serialization
	json: T_Json = $derived.by(() => this.to_json());
	json_serialized: string = $derived(JSON.stringify(this.json));

	// Schema for validation (to be provided by child classes)
	protected abstract schema: T_Schema;

	constructor(options?: Serializable_Options<T_Json>) {
		if (options?.json) {
			// TODO BLOCK ERROR
			//       Argument of type 'Partial<T_Json>' is not assignable to parameter of type 'input<T_Schema>'.
			//   'input<T_Schema>' could be instantiated with an arbitrary type which could be unrelated to 'Partial<T_Json>'.ts(2345)
			// (parameter) options: Serializable_Options<T_Json>
			this.set_json(options.json);
		}
	}

	// Core serialization methods
	abstract to_json(): T_Json;
	// TODO BLOCK `z.input<typeof T_Schema>` instead of `Partial<T_Json>`
	abstract set_json(value: z.input<T_Schema>): void;

	// Standard method for JSON serialization
	toJSON(): T_Json {
		return this.json;
	}

	// Validation using zod schema
	validate(): z.SafeParseReturnType<T_Json, T_Json> {
		return this.schema.safeParse(this.json);
	}

	// Utility method to create a copy with the same data
	clone(): this {
		const clone = new (this.constructor as new () => this)();
		clone.set_json(this.to_json());
		return clone;
	}

	// Static methods are no longer defined here
	// Implementing classes should provide:
	// static create_default(): ClassName { return new ClassName(); }
	// static from_json(json: Partial<ClassName_Json>): ClassName { return new ClassName({json}); }
}
