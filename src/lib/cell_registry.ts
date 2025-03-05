import type {Class_Constructor} from '@ryanatkn/belt/types.js';

import type {Cell} from '$lib/cell.svelte.js';
import type {Zzz} from '$lib/zzz.svelte.js';

/**
 * Registry for managing cell classes and their instances
 */
export class Cell_Registry {
	readonly zzz: Zzz;

	// Store constructors
	readonly #constructors: Map<string, Class_Constructor<any>> = new Map();

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
	 */
	instantiate<T = Cell>(class_name: string, json?: unknown): T | null {
		const constructor = this.#constructors.get(class_name);
		if (!constructor) {
			console.warn(`Class "${class_name}" not registered in registry`);
			return null;
		}

		return new constructor({zzz: this.zzz, json}) as T;
	}

	/**
	 * Decode a value into a cell instance if applicable
	 */
	decode<T = Cell>(value: unknown, class_name: string): T | Array<T> | unknown {
		if (Array.isArray(value)) {
			return value.map((item) => this.decode<T>(item, class_name));
		}

		if (value && typeof value === 'object') {
			return this.instantiate<T>(class_name, value);
		}

		return value;
	}

	/**
	 * Get all registered class names
	 */
	get class_names(): Array<string> {
		return Array.from(this.#constructors.keys());
	}
}
