import {z} from 'zod';
import {format} from 'date-fns';
import {EMPTY_OBJECT} from '@ryanatkn/belt/object.js';

import {get_field_schema, zod_get_schema_keys, type Uuid, type Datetime} from '$lib/zod_helpers.js';
import type {Zzz} from '$lib/zzz.svelte.js';
import {
	get_schema_class_info,
	type Schema_Class_Info,
	HANDLED,
	FILE_SHORT_DATE_FORMAT,
	FILE_DATE_FORMAT,
	FILE_TIME_FORMAT,
	type Cell_Value_Decoder,
} from '$lib/cell_helpers.js';
import type {Schema_Keys, Cell_Json} from '$lib/cell_types.js';

// Base options type that all cells will extend
export interface Cell_Options<T_Schema extends z.ZodType> {
	zzz: Zzz; // TODO needs to be generic
	json?: z.input<T_Schema>;
}

/**
 * The `Cell` is the base class for schema-driven data models in Zzz.
 * The goals are still evolving, but a main idea is to have fully reactive state
 * that can be flexibly snapshotted and reinstantiated in a typesafe, extensible system
 * that uses normal Svelte patterns.
 *
 * The design aims for:
 *
 * - Integration with Svelte's reactivity, encouraging single-depth inheritance
 * 		with Svelte class patterns for both persistent and ephemeral state
 * - Schema-driven parsing/validation and JSON serialization/deserialization via Zod
 * 		(I plan to evaluate ArkType soon)
 * - Custom property encoding/decoding for complex types,
 * 		and no boilerplate for schema-inferrable properties
 * - Lifecycle management with generic instantiation/registration and disposal
 * - Runtime type metadata for reflection
 *
 * Cells are automatically registered in the global registry by `id`,
 * making them discoverable and referenceable throughout the system.
 * Each cell has common properties including `id` and `created`/`updated` timestamps.
 *
 * There are currently a lot of rough edges and missing features!
 * My hope is that this could be generic enough to extract to a library, but it's not there yet.
 * I assume there's a really nice design in this space that takes full advantage of Svelte runes.
 *
 * Many things will be possible with this pattern, but it's still a work in progress.
 */
export abstract class Cell<T_Schema extends z.ZodType = z.ZodType> implements Cell_Json {
	// Base properties from Cell_Json
	id: Uuid = $state()!;
	created: Datetime = $state()!;
	updated: Datetime | null = $state()!;

	readonly schema: T_Schema; // TODO currently Zod, but I'm evaluating ArkType soon - Zzz's goals may justify its runtime weight, or maybe precompilation will eventually beat Zod on that point too - https://github.com/arktypeio/arktype/issues/810

	readonly schema_keys: Array<Schema_Keys<T_Schema>> = $derived.by(() =>
		zod_get_schema_keys(this.schema),
	);
	readonly field_schemas: Map<Schema_Keys<T_Schema>, z.ZodType> = $derived.by(
		() => new Map(this.schema_keys.map((key) => [key, get_field_schema(this.schema, key)])),
	);
	readonly field_schema_info: Map<Schema_Keys<T_Schema>, Schema_Class_Info | null> = $derived(
		new Map(
			this.schema_keys.map((key) => {
				const field_schema = this.field_schemas.get(key);
				if (!field_schema) {
					return [key, null];
				}
				return [key, get_schema_class_info(field_schema)];
			}),
		),
	);

	readonly json: z.output<T_Schema> = $derived(this.to_json());
	readonly json_serialized: string = $derived(JSON.stringify(this.json));
	readonly json_parsed: z.SafeParseReturnType<z.output<T_Schema>, z.output<T_Schema>> = $derived.by(
		() => this.schema.safeParse(this.json),
	);

	// TODO needs to be generic so users can extend it
	readonly zzz: Zzz;

	/**
	 * Type-safe decoders for custom field decoding.
	 * Override in subclasses to handle special field types.
	 *
	 * Each decoder function takes a value of any type and should either:
	 * 1. Return a value (including null) to be assigned to the property
	 * 2. Return undefined to use the default decoding behavior
	 * 3. Return HANDLED to indicate the decoder has fully processed the property
	 *    (virtual properties MUST return HANDLED if they exist in schema but not in class)
	 */
	protected decoders: Cell_Value_Decoder<T_Schema> = {};

	readonly created_date: Date = $derived(new Date(this.created));
	readonly created_formatted_short_date: string = $derived(
		format(this.created_date, FILE_SHORT_DATE_FORMAT),
	);
	readonly created_formatted_date: string = $derived(format(this.created_date, FILE_DATE_FORMAT));
	readonly created_formatted_time: string = $derived(format(this.created_date, FILE_TIME_FORMAT));

	readonly updated_date: Date | null = $derived(this.updated ? new Date(this.updated) : null);
	readonly updated_formatted_short_date: string | null = $derived(
		this.updated_date ? format(this.updated_date, FILE_SHORT_DATE_FORMAT) : null,
	);
	readonly updated_formatted_date: string | null = $derived(
		this.updated_date ? format(this.updated_date, FILE_DATE_FORMAT) : null,
	);
	readonly updated_formatted_time: string | null = $derived(
		this.updated_date ? format(this.updated_date, FILE_TIME_FORMAT) : null,
	);

	/** Stored only between construction and initialization */
	#initial_json: z.input<T_Schema> | undefined;

	constructor(schema: T_Schema, options: Cell_Options<T_Schema>) {
		this.schema = schema;
		this.zzz = options.zzz;
		this.#initial_json = options.json;

		// Don't auto-initialize here - wait for subclass to call init()
		// so its properties initialize and constructor runs
	}

	/**
	 * Initialize the instance with `options.json` data if provided.
	 * Must be called before using the instance -
	 * the current pattern is calling it at the end of subclass constructors.
	 *
	 * We should investigate deferring to callers so e.g. instantiating from the registry
	 * would init automatically, subclasses need no init logic (which can get unwieldy with inheritance),
	 * and then callers could always do custom init patterns if they wanted.
	 *
	 * Can't be called automatically by the Cell's constructor because
	 * the subclass' constructor needs to run first to support field initialization.
	 * A design goal behind the Cell is to support normal TS and Svelte patterns
	 * with the most power and least intrusion. (there's a balance to find from Zzz's POV)
	 */
	protected init(): void {
		const initial_json = this.#initial_json;
		this.#initial_json = undefined;
		this.set_json(initial_json); // `set_json` parses with the schema, so this may be `undefined` and it's fine

		// Register the cell with the global registry
		this.register();
	}

	/**
	 * Clean up resources when this cell is no longer needed.
	 * Should be called before the cell is discarded.
	 */
	dispose(): void {
		this.unregister();
	}

	/** Flag to track registration status - prevents double registration */
	#registered = false;

	/**
	 * Register this cell in the global cell registry.
	 * Called automatically by init().
	 */
	protected register(): void {
		if (this.#registered) {
			console.error(`Cell ${this.constructor.name} is already registered`);
			return;
		}

		this.zzz.cells.set(this.id, this as any); // TODO refactor to avoid casting?
		this.#registered = true;
	}

	/**
	 * Unregister this cell from the global cell registry.
	 * Called automatically by dispose().
	 */
	protected unregister(): void {
		if (!this.#registered) return;

		this.zzz.cells.delete(this.id);
		this.#registered = false;
	}

	/**
	 * For Svelte's $snapshot.
	 */
	toJSON(): z.output<T_Schema> {
		return this.json;
	}

	/**
	 * Encodes the cell's serializable state as JSON.
	 * Use the derived `cell.json` if you don't need a fresh copy.
	 */
	to_json(): z.output<T_Schema> {
		const result: z.output<T_Schema> = {};

		for (const key of this.schema_keys) {
			if (key in this) {
				result[key] = this.encode_property(this[key], key);
			} else {
				console.error(`Property ${key} not found on instance of ${this.constructor.name}`);
			}
		}

		return result;
	}

	/**
	 * Apply JSON data to this instance.
	 * Overwrites all properties including 'id'.
	 */
	set_json(value: z.input<T_Schema> = EMPTY_OBJECT): void {
		try {
			// Parse input with schema - this will apply schema defaults for missing fields.
			// Use empty object if value is undefined to ensure schemas
			// without `.optional()` on their top-level object processes defaults.
			const parsed = this.schema.parse(value);

			// Process each schema key
			for (const key of this.schema_keys) {
				// Get the value from parsed data (might be schema default)
				const parsed_value = parsed[key];

				// Process this schema property
				this.assign_property(key, parsed_value);
			}
		} catch (error) {
			console.error(`Error setting JSON for ${this.constructor.name}:`, error);
			throw error; // Re-throw so tests that expect errors will pass
		}
	}

	/**
	 * Update only the specified properties on this instance.
	 * Preserves current values for any properties not included in the input.
	 */
	set_json_partial(partial_value: Partial<z.input<T_Schema>>): void {
		if (!partial_value || typeof partial_value !== 'object') return; // eslint-disable-line @typescript-eslint/no-unnecessary-condition

		try {
			// Directly process each property in the partial update
			for (const key of Object.keys(partial_value) as Array<Schema_Keys<T_Schema>>) {
				// Skip empty properties
				if (partial_value[key] === undefined) continue;

				// Get the field schema for this property
				const field_schema = this.field_schemas.get(key);
				if (!field_schema) {
					console.error(`Schema key "${key}" not found in schema for ${this.constructor.name}`);
					continue;
				}

				// Parse the individual value through its field schema
				try {
					const parsed_value = field_schema.parse(partial_value[key]);

					// Assign the parsed property
					this.assign_property(key, parsed_value);
				} catch (field_error) {
					console.error(
						`Error parsing property "${key}" for ${this.constructor.name}:`,
						field_error,
					);
					throw field_error;
				}
			}
		} catch (error) {
			console.error(`Error in partial update for ${this.constructor.name}:`, error);
			throw error;
		}
	}

	/**
	 * Encode a value during serialization. Can be overridden for custom encoding logic.
	 * Defaults to Svelte's `$state.snapshot`,
	 * which handles most cases and uses `toJSON` when available,
	 * so overriding `to_json` is sufficient for most cases before overriding `encode`.
	 */
	encode_property(value: unknown, _key: string): unknown {
		return $state.snapshot(value);
	}

	/**
	 * Decode a value based on its schema type information.
	 * This handles instantiating classes, transforming arrays, and special types.
	 *
	 * Complex property types might require custom handling in parser functions
	 * rather than using this general decoding mechanism.
	 */
	decode_property<K extends Schema_Keys<T_Schema>>(value: unknown, key: K): this[K] {
		const schema_info = this.field_schema_info.get(key);
		if (!schema_info) return value as this[K];

		// Handle arrays of cells
		if (schema_info.is_array && Array.isArray(value)) {
			if (schema_info.element_class) {
				return value.map((item) => {
					const instance = this.#instantiate_class(schema_info.element_class, item);
					// Return the item if instantiation returns null
					return instance !== null ? instance : item;
				}) as this[K];
			}
			return value as this[K];
		}

		// Handle individual cell
		if (schema_info.class_name && value && typeof value === 'object') {
			const instance = this.#instantiate_class(schema_info.class_name, value);
			// Return the original value if instantiation returns null
			return (instance !== null ? instance : value) as this[K];
		}

		// Handle special types
		if (schema_info.type === 'ZodMap' && Array.isArray(value)) {
			return new Map(value) as this[K];
		}
		if (schema_info.type === 'ZodSet' && Array.isArray(value)) {
			return new Set(value) as this[K];
		}
		if (schema_info.type === 'ZodBranded' && value !== null && value !== undefined) {
			try {
				// Use the schema directly to parse branded types
				const field_schema = this.field_schemas.get(key);
				return (field_schema?.parse(value) ?? value) as this[K];
			} catch (e) {
				console.error(`Failed to parse branded type for ${key}:`, e);
				return value as this[K];
			}
		}

		return value as this[K];
	}

	/**
	 * Process a single schema property during JSON deserialization.
	 * This method handles the workflow for mapping schema properties to instance properties.
	 *
	 * Flow:
	 * 1. If a decoder exists for this property, try to use it
	 * 2. If decoder returns HANDLED, consider the property fully handled (short circuit)
	 * 3. If decoder returns a value other than HANDLED or undefined, use that value
	 * 4. If decoder returns undefined, fall through to standard decoding
	 * 5. For properties not directly represented in the class instance but defined
	 *    in the schema, the decoder MUST return HANDLED to indicate proper handling
	 */
	protected assign_property(key: Schema_Keys<T_Schema>, value: unknown): void {
		// 1. Check if we have a property and decoder for this key
		const has_property = key in this;
		const has_decoder = key in this.decoders;

		// 2. If we don't have a property or decoder, log an error and bail
		if (!has_property && !has_decoder) {
			console.error(
				`Schema key "${key}" in ${this.constructor.name} has no matching property or decoder. ` +
					`Consider adding the property or a decoder.`,
			);
			return;
		}

		// 3. Try to use the decoder if available
		if (has_decoder) {
			const decoder = this.decoders[key];
			if (decoder) {
				const decoded = decoder(value);

				// 3a. If decoder returns HANDLED, it signals complete handling (short circuit)
				if (decoded === HANDLED) {
					return;
				}

				// 3b. If decoder returns a defined value AND we have a property, assign it
				// Note: this allows null values to be assigned
				if (decoded !== undefined && has_property) {
					(this as any)[key] = decoded;
					return;
				}

				// 3c. If decoder returns undefined, fall through to standard decoding

				// 3d. If we don't have a property but have a decoder that didn't return HANDLED,
				// that's an error - virtual properties MUST be explicitly handled
				if (!has_property) {
					console.error(
						`Decoder for schema property "${key}" in ${this.constructor.name} didn't return HANDLED. ` +
							`Virtual properties (not present on class) must explicitly return HANDLED.`,
					);
					return;
				}
			}
		}

		// 4. Use standard decoding if we have a property and value
		if (has_property && value !== undefined) {
			const decoded = this.decode_property(value, key);
			this[key] = decoded;
		}
	}

	/** Generic clone method that works for any subclass. */
	clone(json?: z.input<T_Schema>, options?: Cell_Options<T_Schema>): this {
		const constructor = this.constructor as new (options: Cell_Options<T_Schema>) => this;

		const {id: _, ...current_json} = this.json;

		try {
			return new constructor({
				...options,
				zzz: this.zzz,
				json: structuredClone(json ? {...current_json, ...json} : current_json),
			});
		} catch (error) {
			console.error(`Failed to clone instance of ${constructor.name}:`, error);
			throw new Error(`Failed to clone: ${error instanceof Error ? error.message : String(error)}`);
		}
	}

	#instantiate_class(class_name: string | undefined, json: unknown, options?: object): unknown {
		if (!class_name) {
			console.error('No class name provided for instantiation');
			return null;
		}

		const instance = this.zzz.registry.maybe_instantiate(class_name as any, json, options);
		if (!instance) console.error(`Failed to instantiate ${class_name}`);
		return instance;
	}
}
