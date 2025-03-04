import type {Cell} from '$lib/cell.svelte.js';
import type {Zzz} from './zzz.svelte.js';

// TODO extract helper?
type Class_Constructor<T> = new (options: any) => T;

/**
 * Registry for managing class constructors and handling instantiation
 */
export class Cell_Registry<T_Zzz extends Zzz = Zzz> {
	readonly zzz: T_Zzz;

	// Map of class names to constructors
	readonly #constructors: Map<string, Class_Constructor<any>> = new Map();

	constructor(zzz: T_Zzz) {
		this.zzz = zzz;
	}

	/**
	 * Register a class constructor with its name
	 */
	register<T_Class extends Cell<any, any>>(constructor: Class_Constructor<T_Class>): void {
		// Use the constructor's name as the key
		const class_name = constructor.name;
		this.#constructors.set(class_name, constructor);
	}

	/**
	 * Create an instance of a registered class by name
	 */
	instantiate<T>(class_name: string, json?: any): T | null {
		const constructor = this.#constructors.get(class_name);
		if (!constructor) {
			console.warn(`Class "${class_name}" not registered in registry`);
			return null;
		}

		return new constructor({zzz: this.zzz, json}) as T;
	}

	/**
	 * Decode a value into a class instance if applicable
	 */
	decode<T>(value: unknown, class_name: string): T | Array<T> | unknown {
		if (Array.isArray(value)) {
			return value.map((item) => this.decode(item, class_name));
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
