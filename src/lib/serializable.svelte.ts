// serializable.svelte.ts

import type {z} from 'zod';

export interface Serializable_Constructor<T_Class extends Serializable<any, any>, T_Json = any> {
	from_json: (json?: T_Json) => T_Class;
}

// TODO maybe rename to `Json_Serializable` to be more explicit?
export abstract class Serializable<T_Json, T_Schema extends z.ZodType> {
	readonly schema: T_Schema;

	readonly json: T_Json = $derived.by(() => this.to_json());
	readonly json_serialized: string = $derived(JSON.stringify(this.json));

	constructor(schema: T_Schema) {
		this.schema = schema;
	}

	abstract to_json(): T_Json;
	abstract set_json(value?: z.input<T_Schema>): void;

	toJSON(): T_Json {
		return this.json;
	}

	validate(): z.SafeParseReturnType<z.output<T_Schema>, z.output<T_Schema>> {
		return this.schema.safeParse(this.json);
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
