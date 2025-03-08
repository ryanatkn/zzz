import type {Class_Constructor} from '@ryanatkn/belt/types.js';

import type {Cell} from '$lib/cell.svelte.js';
import type {Zzz, Cell_Registry_Map} from '$lib/zzz.svelte.js';

/**
 * Registry for managing cell classes and their instances
 */
export class Cell_Registry {
	readonly zzz: Zzz;

	// Store constructors
	readonly #constructors: Map<string, Class_Constructor<any>> = new Map();

	class_names: Array<string> = $derived(Array.from(this.#constructors.keys()));

	constructor(zzz: Zzz) {
		this.zzz = zzz;
	}

	/**
	 * Register a cell class with the registry
	 */
	register<T extends Cell>(constructor: Class_Constructor<T>): void {
		const class_name = constructor.name;
		this.#constructors.set(class_name, constructor);
	}

	/**
	 * Create an instance of a registered cell class by name
	 * Type is automatically inferred from class name literals
	 */
	instantiate<K extends keyof Cell_Registry_Map>(
		class_name: K,
		json?: unknown,
	): Cell_Registry_Map[K] | null;
	instantiate(class_name: string, json?: unknown): Cell | null;
	instantiate(class_name: string, json?: unknown): Cell | null {
		const constructor = this.#constructors.get(class_name);
		if (!constructor) {
			return null;
		}

		// TODO @many maybe optionally forward additional rest options?
		return new constructor({zzz: this.zzz, json});
	}

	/**
	 * Decode a value into a cell instance if applicable
	 */
	decode<K extends keyof Cell_Registry_Map>(
		value: unknown,
		class_name: K,
	): Cell_Registry_Map[K] | Array<Cell_Registry_Map[K]> | unknown;
	decode(value: unknown, class_name: string): Cell | Array<Cell> | unknown;
	decode(value: unknown, class_name: string): Cell | Array<Cell> | unknown {
		if (Array.isArray(value)) {
			return value.map((item) => this.decode(item, class_name));
		}

		if (value && typeof value === 'object') {
			return this.instantiate(class_name, value) ?? value; // TODO defaults to the value, but is that right? should it be null?
		}

		return value;
	}
}
