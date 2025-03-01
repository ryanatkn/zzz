// serializable.svelte.ts

import type {z} from 'zod';

/**
 * Describes the expected static methods on Serializable classes
 */
export interface Serializable_Constructor<T extends Serializable<any, any>, J = any> {
	new (schema: z.ZodTypeAny): T;
	create_default: () => T;
	from_json: (json: Partial<J>) => T;
}

// TODO maybe rename to `Json_Serializable`?
export abstract class Serializable<T_Json, T_Schema extends z.ZodType> {
	readonly schema: T_Schema;

	readonly json: T_Json = $derived.by(() => this.to_json());
	readonly json_serialized: string = $derived(JSON.stringify(this.json));

	constructor(schema: T_Schema) {
		this.schema = schema;
	}

	abstract to_json(): T_Json;
	abstract set_json(value: z.input<T_Schema>): void;

	toJSON(): T_Json {
		return this.json;
	}

	validate(): z.SafeParseReturnType<z.output<T_Schema>, z.output<T_Schema>> {
		return this.schema.safeParse(this.json);
	}

	clone(): this {
		// Pass the schema as first argument when creating a new instance
		const clone = new (this.constructor as any)(this.schema);
		clone.set_json(this.to_json() as z.input<T_Schema>);
		return clone;
	}
}
