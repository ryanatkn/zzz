import type {Class_Constructor} from '@ryanatkn/belt/types.js';
import type {z} from 'zod';
import {DEV} from 'esm-env';

import type {Cell} from '$lib/cell.svelte.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import type {Cell_Registry_Map} from '$lib/cell_classes.js';

/**
 * Error thrown when attempting to instantiate an unregistered class.
 */
export class Class_Not_Registered_Error extends Error {
	readonly class_name: string;
	readonly available_classes: Array<string>;

	constructor(class_name: string, available_classes: Array<string>) {
		const message = `Class "${class_name}" is not registered. Available classes: ${available_classes.join(', ')}`;
		super(message);
		this.name = 'Class_Not_Registered_Error';
		this.class_name = class_name;
		this.available_classes = available_classes;
	}
}

/**
 * Registry for managing cell classes and their instances.
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
	 * Register a cell class with the registry.
	 */
	register<T extends Cell>(constructor: Class_Constructor<T>): void {
		const class_name = constructor.name;
		if (DEV && this.#constructors.has(class_name)) {
			console.error(`Class "${class_name}" is already registered, overwriting.`);
		}
		this.#constructors.set(class_name, constructor);
	}

	/**
	 * Unregister a cell class from the registry.
	 */
	unregister(class_name: string): void {
		if (DEV && !this.#constructors.has(class_name)) {
			console.error(`Cannot unregister "${class_name}": class not found in registry`);
		}
		this.#constructors.delete(class_name);
	}

	/**
	 * Attempt to instantiate a class, returning null if not found.
	 * Logs an error in development if the class isn't registered.
	 */
	maybe_instantiate<K extends keyof Cell_Registry_Map>(
		class_name: K,
		json?: Cell_Registry_Map[K] extends Cell<infer T_Schema> ? z.input<T_Schema> : never,
		options?: object,
	): Cell_Registry_Map[K] | null {
		const constructor = this.#constructors.get(class_name);
		if (!constructor) {
			if (DEV) {
				console.error(
					`Class "${class_name}" is not registered. Available classes: ${this.class_names.join(', ')}`,
				);
			}
			return null;
		}

		// Create a new instance with the provided options and cast to the specific type
		return new constructor({...options, zzz: this.zzz, json}) as Cell_Registry_Map[K];
	}

	/**
	 * Create an instance of a registered cell class by name.
	 * Throws if the class isn't found.
	 *
	 * Type is automatically inferred from class name literals.
	 */
	instantiate<K extends keyof Cell_Registry_Map>(
		class_name: K,
		json?: Cell_Registry_Map[K] extends Cell<infer T_Schema> ? z.input<T_Schema> : never,
		options?: object,
	): Cell_Registry_Map[K] {
		const constructor = this.#constructors.get(class_name);
		if (!constructor) {
			throw new Class_Not_Registered_Error(class_name, this.class_names);
		}

		// Create a new instance with the provided options and cast to the specific type
		return new constructor({...options, zzz: this.zzz, json}) as Cell_Registry_Map[K];
	}
}
