import {SvelteMap} from 'svelte/reactivity';
import {Uuid} from '$lib/zod_helpers.js';

// TODO need better caching

/**
 * Interface for objects that can be stored in an indexed collection
 */
export interface Indexed_Item {
	id: Uuid; // updated to use Uuid instead of string
}

/**
 * Type-safe configuration for additional indexes
 */
export interface Index_Config<T, K extends string, V> {
	key: K;
	extractor: (item: T) => V;
	multi?: boolean; // Whether this index maps to multiple items
}

export type Index_Value_Types<K extends string> = Record<K, any>;

export interface Indexed_Collection_Options<
	T extends Indexed_Item,
	K extends string,
	V extends Index_Value_Types<K> = Record<K, any>,
> {
	indexes?: Array<Index_Config<T, K, V[K]>>;
	initial_items?: Array<T>;
}

/**
 * A helper class for managing collections that need efficient lookups
 * with automatic index maintenance
 */
export class Indexed_Collection<
	T extends Indexed_Item,
	K extends string = never,
	V extends Index_Value_Types<K> = Record<K, any>,
> {
	// The main collection of items
	all: Array<T> = $state([]);

	// The primary index by ID keyed by Uuid
	readonly by_id: SvelteMap<Uuid, T> = new SvelteMap();

	// Direct position index lookup for O(1) array position access - integer based
	readonly position_index: SvelteMap<Uuid, number> = new SvelteMap();

	// Fractional order index for stable ordering with minimum updates
	readonly fractional_index: SvelteMap<Uuid, number> = new SvelteMap();

	// Additional single-value indexes (one key maps to one item)
	readonly single_indexes: Partial<Record<K, SvelteMap<any, T>>> = {};

	// Additional multi-value indexes (one key maps to many items)
	readonly multi_indexes: Partial<Record<K, SvelteMap<any, Array<T>>>> = {};

	// Fractional index constants
	readonly #POSITION_STEP = 1000.0; // Standard step for normal indexing
	readonly #REBALANCE_THRESHOLD = 1.0; // When positions get this close, rebalance

	#configs: Array<Index_Config<T, K, any>> = [];

	constructor(options?: Indexed_Collection_Options<T, K, V>) {
		// Set up additional indexes
		if (options?.indexes) {
			this.#configs = options.indexes;

			// Initialize the index maps
			for (const config of this.#configs) {
				if (config.multi) {
					this.multi_indexes[config.key] = new SvelteMap();
				} else {
					this.single_indexes[config.key] = new SvelteMap();
				}
			}
		}

		// Add any initial items
		if (options?.initial_items) {
			for (const item of options.initial_items) {
				this.add(item);
			}
		}
	}

	toJSON(): Array<any> {
		return $state.snapshot(this.all);
	}

	/**
	 * Get a fractional position value between two existing positions.
	 */
	#get_fractional_position(before_position?: number, after_position?: number): number {
		// If no positions provided, use a standard step
		if (before_position === undefined && after_position === undefined) {
			return this.#POSITION_STEP;
		}

		// If only after position exists, place before it
		if (before_position === undefined && after_position !== undefined) {
			return after_position - this.#POSITION_STEP;
		}

		// If only before position exists, place after it
		if (before_position !== undefined && after_position === undefined) {
			return before_position + this.#POSITION_STEP;
		}

		// Get midpoint between positions
		return (before_position! + after_position!) / 2;
	}

	/**
	 * Check if fractional index needs rebalancing and perform if necessary
	 */
	#check_rebalance_fractional_positions(): void {
		if (this.all.length < 2) return;

		// Check if rebalance is needed by looking at adjacent positions
		let needs_rebalance = false;

		// Optimization: Instead of sorting the entire array (O(n log n)), we can
		// iterate through items in their fractional order to find problematic gaps
		// in a single pass (O(n))

		// First, collect all items with their fractional positions
		const items_with_positions: Array<[T, number]> = [];
		for (const item of this.all) {
			const pos = this.fractional_index.get(item.id);
			if (pos !== undefined) {
				items_with_positions.push([item, pos]);
			}
		}

		// Sort by position (this is still O(n log n), but only done when checking)
		items_with_positions.sort((a, b) => a[1] - b[1]);

		// Check for small gaps in a single pass
		for (let i = 1; i < items_with_positions.length; i++) {
			const prev_pos = items_with_positions[i - 1][1];
			const curr_pos = items_with_positions[i][1];
			const diff = curr_pos - prev_pos;

			if (diff < this.#REBALANCE_THRESHOLD) {
				needs_rebalance = true;
				break;
			}
		}

		if (needs_rebalance) {
			// Optimization: Avoid re-sorting by using already sorted array
			for (let i = 0; i < items_with_positions.length; i++) {
				const [item, _] = items_with_positions[i];
				this.fractional_index.set(item.id, (i + 1) * this.#POSITION_STEP);
			}
		}
	}

	/**
	 * Optimized implementation that only updates position indexes when necessary
	 */
	#update_position_indexes(start_index: number = 0): void {
		// Early exit if no updates needed
		if (start_index >= this.all.length) return;

		// Only update what's necessary
		for (let i = start_index; i < this.all.length; i++) {
			this.position_index.set(this.all[i].id, i);
		}
	}

	/**
	 * Add multiple items to the collection at once with improved performance
	 */
	add_many(items: Array<T>): Array<T> {
		if (!items.length) return [];

		// Remember starting position for optimizing index updates
		const start_position = this.all.length;

		// Reserve space for fractional positions
		const positions: Array<number> = new Array(items.length);
		let last_frac_position =
			start_position > 0 ? this.fractional_index.get(this.all[start_position - 1].id) || 0 : 0;

		// Pre-compute fractional positions
		for (let i = 0; i < items.length; i++) {
			last_frac_position += this.#POSITION_STEP;
			positions[i] = last_frac_position;
		}

		// Add all items to main array
		this.all.push(...items);

		// Batch update all indexes at once - much more efficient
		for (let i = 0; i < items.length; i++) {
			const item = items[i];
			const position = start_position + i;

			// Update primary indexes
			this.by_id.set(item.id, item);
			this.position_index.set(item.id, position);
			this.fractional_index.set(item.id, positions[i]);

			// Update additional indexes
			for (const config of this.#configs) {
				const key = config.extractor(item);
				if (key !== undefined && key !== null) {
					if (config.multi) {
						const collection = this.multi_indexes[config.key]!.get(key) || [];
						collection.push(item);
						this.multi_indexes[config.key]!.set(key, collection);
					} else {
						this.single_indexes[config.key]!.set(key, item);
					}
				}
			}
		}

		return items;
	}

	/**
	 * Remove multiple items efficiently with optimized index updates
	 */
	remove_many(ids: Array<Uuid>): number {
		if (!ids.length) return 0;

		// Use a Set for O(1) lookups
		const id_set = new Set(ids);
		let removed_count = 0;

		// First build a removal map to avoid repeated lookups
		const to_remove_indices: Array<number> = [];
		const to_remove_items: Array<T> = [];

		// Identify items to remove and their indices
		for (let i = this.all.length - 1; i >= 0; i--) {
			const item = this.all[i];
			if (id_set.has(item.id)) {
				to_remove_indices.push(i);
				to_remove_items.push(item);
				removed_count++;
			}
		}

		// Exit early if nothing to remove
		if (removed_count === 0) return 0;

		// Find the lowest affected index for updating positions later
		const lowest_affected_index = Math.min(...to_remove_indices);

		// Remove items from main array (from end to start to avoid index shifts)
		for (const index of to_remove_indices) {
			this.all.splice(index, 1);
		}

		// Clear removed items from indexes
		for (const item of to_remove_items) {
			// Clear from primary indexes
			this.by_id.delete(item.id);
			this.position_index.delete(item.id);
			this.fractional_index.delete(item.id);

			// Update secondary indexes
			for (const config of this.#configs) {
				const key = config.extractor(item);
				if (key == null) continue;

				if (config.multi) {
					const multi_index = this.multi_indexes[config.key]!;
					const collection = multi_index.get(key);

					if (collection) {
						const updated = collection.filter((i) => i.id !== item.id);
						if (updated.length === 0) {
							multi_index.delete(key);
						} else {
							multi_index.set(key, updated);
						}
					}
				} else {
					const single_index = this.single_indexes[config.key]!;
					const mapped_item = single_index.get(key);

					if (mapped_item && mapped_item.id === item.id) {
						single_index.delete(key);
					}
				}
			}
		}

		// Update position indexes for remaining items
		if (removed_count > 0 && lowest_affected_index < this.all.length) {
			this.#update_position_indexes(lowest_affected_index);
		}

		return removed_count;
	}

	/**
	 * Add an item to the collection and update all indexes
	 */
	add(item: T): T {
		// Add to the end of the array
		const position = this.all.length;
		this.all.push(item);
		this.by_id.set(item.id, item);

		// Position index always reflects the actual array index
		this.position_index.set(item.id, position);

		// Calculate fractional position for stable ordering
		// If this is the first item, use the standard step; otherwise
		// place it after the last item
		const frac_position =
			this.all.length > 1
				? this.#get_fractional_position(
						this.fractional_index.get(this.all[this.all.length - 2].id),
						undefined,
					)
				: this.#POSITION_STEP;

		this.fractional_index.set(item.id, frac_position);

		// Update all additional indexes
		for (const config of this.#configs) {
			const key = config.extractor(item);
			if (key !== undefined && key !== null) {
				if (config.multi) {
					const collection = this.multi_indexes[config.key]!.get(key) || [];
					collection.push(item);
					this.multi_indexes[config.key]!.set(key, collection);
				} else {
					this.single_indexes[config.key]!.set(key, item);
				}
			}
		}

		return item;
	}

	/**
	 * Optimized implementation of add_first with lazy position index
	 */
	add_first(item: T): T {
		// Add to beginning of array
		this.all.unshift(item);
		this.by_id.set(item.id, item);

		// Only update the position for the new item
		this.position_index.set(item.id, 0);

		// Invalidate other position indexes to be recomputed when needed
		for (const [id, position] of this.position_index.entries()) {
			if (id !== item.id) {
				// Only update positions we know have changed
				this.position_index.set(id, position + 1);
			}
		}

		// Calculate fractional position
		const frac_position =
			this.all.length > 1
				? this.#get_fractional_position(undefined, this.fractional_index.get(this.all[1].id))
				: this.#POSITION_STEP;

		this.fractional_index.set(item.id, frac_position);

		// Check if we need to rebalance fractional positions
		this.#check_rebalance_fractional_positions();

		// Update secondary indexes
		for (const config of this.#configs) {
			const key = config.extractor(item);
			if (key !== undefined && key !== null) {
				if (config.multi) {
					const collection = this.multi_indexes[config.key]!.get(key) || [];
					collection.unshift(item);
					this.multi_indexes[config.key]!.set(key, collection);
				} else {
					this.single_indexes[config.key]!.set(key, item);
				}
			}
		}

		return item;
	}

	/**
	 * Insert an item at a specific position with optimal index updates
	 */
	insert_at(item: T, index: number): T {
		if (index < 0 || index > this.all.length) {
			throw new Error(
				`Insert index ${index} out of bounds for collection of size ${this.all.length}`,
			);
		}

		if (index === 0) {
			return this.add_first(item);
		}

		if (index === this.all.length) {
			return this.add(item);
		}

		// Insert into array
		this.all.splice(index, 0, item);
		this.by_id.set(item.id, item);

		// Update position indexes for affected items - MUST reflect array positions
		this.#update_position_indexes(index);

		// Calculate fractional position between surrounding items
		let frac_position: number;

		if (index === 0) {
			// First position - place before the next item
			frac_position =
				this.all.length > 1
					? this.#get_fractional_position(undefined, this.fractional_index.get(this.all[1].id))
					: this.#POSITION_STEP;
		} else if (index === this.all.length - 1) {
			// Last position - place after the previous item
			frac_position = this.#get_fractional_position(
				this.fractional_index.get(this.all[index - 1].id),
				undefined,
			);
		} else {
			// Middle position - place between surrounding items
			frac_position = this.#get_fractional_position(
				this.fractional_index.get(this.all[index - 1].id),
				this.fractional_index.get(this.all[index + 1].id),
			);
		}

		this.fractional_index.set(item.id, frac_position);

		// Check if rebalance needed
		this.#check_rebalance_fractional_positions();

		// Update all additional indexes
		for (const config of this.#configs) {
			const key = config.extractor(item);
			if (key !== undefined && key !== null) {
				if (config.multi) {
					const collection = this.multi_indexes[config.key]!.get(key) || [];
					// Find the right position in the collection based on array position
					const insert_index = collection.findIndex(
						(existing) => this.position_index.get(existing.id)! > index,
					);

					if (insert_index === -1) {
						collection.push(item);
					} else {
						collection.splice(insert_index, 0, item);
					}

					this.multi_indexes[config.key]!.set(key, collection);
				} else {
					this.single_indexes[config.key]!.set(key, item);
				}
			}
		}

		return item;
	}

	/**
	 * Remove an item by its ID and update all indexes
	 */
	remove(id: Uuid): boolean {
		const item = this.by_id.get(id);
		if (!item) return false;

		const index = this.position_index.get(id);
		if (index === undefined) return false;

		// Remove from array
		this.all.splice(index, 1);
		this.by_id.delete(id);
		this.position_index.delete(id);
		this.fractional_index.delete(id);

		// Update position indexes for all subsequent items
		this.#update_position_indexes(index);

		// Update all additional indexes
		for (const config of this.#configs) {
			const key = config.extractor(item);
			if (key == null) continue;
			if (config.multi) {
				const multi_index = this.multi_indexes[config.key]!;
				const collection = multi_index.get(key);

				if (collection) {
					// Filter out the removed item
					const updated = collection.filter((i) => i.id !== id);

					// If no items left with this key, remove the key from the index
					if (updated.length === 0) {
						multi_index.delete(key);
					} else {
						multi_index.set(key, updated);
					}
				}
			} else {
				// For single-value indexes, only remove if this item is mapped to this key
				const single_index = this.single_indexes[config.key]!;
				const mapped_item = single_index.get(key);

				if (mapped_item && mapped_item.id === id) {
					single_index.delete(key);
				}
			}
		}

		return true;
	}

	/**
	 * Get an item by its ID
	 */
	get(id: Uuid): T | undefined {
		return this.by_id.get(id);
	}

	/**
	 * Check if the collection has an item with the given ID
	 */
	has(id: Uuid): boolean {
		return this.by_id.has(id);
	}

	/**
	 * Get the array index of an item by its ID with improved caching
	 */
	index_of(id: Uuid): number | undefined {
		// Try the cache first
		const cached_index = this.position_index.get(id);
		if (cached_index !== undefined) {
			// Verify the cached position is correct
			if (this.all[cached_index]?.id === id) {
				return cached_index;
			}
		}

		// Cache miss or invalid cache, find the item in the array
		const item = this.by_id.get(id);
		if (!item) return undefined;

		// Scan the array to find the item
		for (let i = 0; i < this.all.length; i++) {
			if (this.all[i].id === id) {
				// Update the cache and return
				this.position_index.set(id, i);
				return i;
			}
		}

		// Item not found in array but exists in by_id (inconsistent state)
		return undefined;
	}

	/**
	 * Get items sorted by their fractional index
	 */
	get_ordered_items(): Array<T> {
		return [...this.all].sort((a, b) => {
			const pos_a = this.fractional_index.get(a.id) || 0;
			const pos_b = this.fractional_index.get(b.id) || 0;
			return pos_a - pos_b;
		});
	}

	/**
	 * Reorder items in the collection
	 */
	reorder(from_index: number, to_index: number): void {
		if (from_index === to_index) return;
		if (from_index < 0 || to_index < 0) return;
		if (from_index >= this.all.length || to_index >= this.all.length) return;

		// Get the item to move
		const item = this.all[from_index];

		// Remove from array and reinsert at new position
		this.all.splice(from_index, 1);
		this.all.splice(to_index, 0, item);

		// Update position indexes for affected items
		const start_index = Math.min(from_index, to_index);
		const end_index = Math.max(from_index, to_index);

		for (let i = start_index; i <= end_index; i++) {
			this.position_index.set(this.all[i].id, i);
		}

		// Calculate new fractional position for the moved item
		let new_frac_position: number;

		if (to_index === 0) {
			// Moving to start
			new_frac_position = this.#get_fractional_position(
				undefined,
				this.fractional_index.get(this.all[1]?.id),
			);
		} else if (to_index === this.all.length - 1) {
			// Moving to end
			new_frac_position = this.#get_fractional_position(
				this.fractional_index.get(this.all[to_index - 1]?.id),
				undefined,
			);
		} else {
			// Moving to middle
			new_frac_position = this.#get_fractional_position(
				this.fractional_index.get(this.all[to_index - 1]?.id),
				this.fractional_index.get(this.all[to_index + 1]?.id),
			);
		}

		// Update fractional position
		this.fractional_index.set(item.id, new_frac_position);

		// Check if rebalance needed
		this.#check_rebalance_fractional_positions();
	}

	/**
	 * Get the current count of items
	 */
	get size(): number {
		return this.all.length;
	}

	/**
	 * Clear all items and reset indexes
	 */
	clear(): void {
		this.all.length = 0;
		this.by_id.clear();
		this.position_index.clear();
		this.fractional_index.clear();

		// Clear all additional indexes
		for (const config of this.#configs) {
			if (config.multi) {
				this.multi_indexes[config.key]!.clear();
			} else {
				this.single_indexes[config.key]!.clear();
			}
		}
	}

	/**
	 * Get all items matching an indexed property value
	 *
	 * @param index_key The indexed property name
	 * @param value The value to filter by
	 */
	where<Key extends K>(index_key: Key, value: V[Key]): Array<T> {
		const multi_index = this.multi_indexes[index_key];
		if (multi_index) {
			return [...(multi_index.get(value) || [])];
		}

		const single_index = this.single_indexes[index_key];
		if (single_index) {
			const item = single_index.get(value);
			return item ? [item] : [];
		}

		return [];
	}

	/**
	 * Get the first N items matching an indexed property value
	 *
	 * @param index_key The indexed property name
	 * @param value The value to filter by
	 * @param limit Maximum number of items to return
	 */
	first<Key extends K>(index_key: Key, value: V[Key], limit: number): Array<T> {
		// Handle edge cases with limit
		if (limit <= 0) return [];

		const items = this.where(index_key, value);
		return items.slice(0, limit);
	}

	/**
	 * Get the latest N items matching an indexed property value
	 *
	 * @param index_key The indexed property name
	 * @param value The value to filter by
	 * @param limit Maximum number of items to return
	 */
	latest<Key extends K>(index_key: Key, value: V[Key], limit: number): Array<T> {
		// Handle edge cases with limit
		if (limit <= 0) return [];

		const items = this.where(index_key, value);
		return items.slice(-Math.min(limit, items.length));
	}

	// TODO make this
	/**
	 * Optimized related method with improved property path resolution
	 */
	related<S extends Record<string, any>>(
		items: Array<S> | undefined,
		property_name: string,
	): Array<T> {
		if (!items?.length) return [];

		const result: Array<T> = [];
		const seen_ids: Set<Uuid> = new Set(); // Prevent duplicates

		// Pre-compute path parts outside the loop for efficiency
		const has_complex_path = property_name.includes('.') || property_name.includes('[');
		const path_parts = has_complex_path ? property_name.split('.') : null;

		for (const item of items) {
			let foreign_key: Uuid | undefined;

			if (has_complex_path && path_parts) {
				foreign_key = this.#resolve_path(item, path_parts);
			} else {
				foreign_key = item[property_name];
			}

			if (foreign_key && !seen_ids.has(foreign_key)) {
				const related_item = this.by_id.get(foreign_key);
				if (related_item) {
					result.push(related_item);
					seen_ids.add(foreign_key);
				}
			}
		}

		return result;
	}

	/**
	 * Helper function to resolve a property path
	 */
	#resolve_path(obj: any, path_parts: Array<string>): any {
		let current: any = obj;

		for (let i = 0; i < path_parts.length && current != null; i++) {
			const part = path_parts[i];

			if (part.includes('[') && part.includes(']')) {
				const match = /^([^[]+)\[(\d+)\]$/.exec(part);
				if (match) {
					const [_, array_name, index_str] = match;
					const array = current[array_name];
					if (Array.isArray(array)) {
						const index = parseInt(index_str, 10);
						current = array[index];
					} else {
						return undefined;
					}
				}
			} else {
				current = current[part];
			}
		}

		return current;
	}

	// TODO add `many_by` for arrays?
	/**
	 * Get an item by a single-value index
	 */
	by<Key extends K>(index_key: Key, value: V[Key]): T | undefined {
		return this.single_indexes[index_key]?.get(value);
	}
}
