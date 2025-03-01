// serializable.svelte.ts

import type {Json_Object} from '@ryanatkn/belt/json.js';

export abstract class Serializable<T_Json extends Json_Object> {
	json: T_Json = $derived.by(() => this.to_json());
	json_serialized: string = $derived(JSON.stringify(this.json));

	abstract to_json(): T_Json;
	abstract set_json(value: Partial<T_Json>): void;

	toJSON(): T_Json {
		return this.json;
	}

	// Optional static methods that implementations can provide
	// static create_default?(): T_Json;
	// static parse?(value: unknown): T_Json;
	// static validate?(value: T_Json): Array<string> | null; // Returns validation errors if any
}
