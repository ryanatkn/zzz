// @vitest-environment jsdom

import {test, expect, describe, beforeEach} from 'vitest';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import {
	create_single_index,
	create_multi_index,
	create_derived_index,
} from '$lib/indexed_collection_helpers.js';
import {Uuid} from '$lib/zod_helpers.js';

// Test item representing a document
interface Test_Document {
	id: Uuid;
	title: string;
	author: string;
	tags: Array<string>;
	category: string;
	created: Date;
	rating: number;
	featured: boolean;
}

// Helper to create document items with default values that can be overridden
const create_document = (overrides: Partial<Test_Document> = {}): Test_Document => ({
	id: Uuid.parse(undefined),
	title: 'default_title',
	author: 'default_author',
	tags: ['tag1'],
	category: 'category1',
	created: new Date(),
	rating: 3,
	featured: false,
	...overrides,
});

// Helper functions for ID-based object equality checks
const has_item_with_id = (array: Array<{id: Uuid}>, item: {id: Uuid}): boolean =>
	array.some((i) => i.id === item.id);

describe('Indexed_Collection - Query Capabilities', () => {
	let collection: Indexed_Collection<Test_Document>;
	let docs: Array<Test_Document>;

	beforeEach(() => {
		// Create a collection with various indexes
		collection = new Indexed_Collection<Test_Document>({
			indexes: [
				// Single value indexes
				create_single_index('by_title', (doc) => doc.title.toLowerCase()), // Case insensitive
				create_single_index('by_author', (doc) => doc.author), // Case sensitive

				// Multi value indexes
				create_multi_index('by_category', (doc) => doc.category),
				create_multi_index('by_tag', (doc) => doc.tags),
				create_multi_index('by_rating', (doc) => doc.rating),
				create_multi_index('by_featured', (doc) => (doc.featured ? 'yes' : 'no')),
				create_multi_index('by_year', (doc) => doc.created.getFullYear()),

				// Derived indexes
				create_derived_index(
					'featured_recent',
					(collection) => {
						return collection.all
							.filter((doc) => doc.featured)
							.sort((a, b) => b.created.getTime() - a.created.getTime())
							.slice(0, 5); // Top 5 recent featured items
					},
					{
						matches: (doc) => doc.featured,
						on_add: (items, doc) => {
							if (!doc.featured) return items;

							// Find the right position based on date (newer items first)
							const index = items.findIndex(
								(existing) => doc.created.getTime() > existing.created.getTime(),
							);

							if (index === -1) {
								items.push(doc);
							} else {
								items.splice(index, 0, doc);
							}

							// Maintain max size
							if (items.length > 5) {
								items.length = 5;
							}
							return items;
						},
						on_remove: (items, doc) => {
							const index = items.findIndex((item) => item.id === doc.id);
							if (index !== -1) {
								items.splice(index, 1);
							}
							return items;
						},
					},
				),
				create_derived_index(
					'high_rated',
					(collection) => collection.all.filter((doc) => doc.rating >= 4),
					{
						matches: (doc) => doc.rating >= 4,
						on_add: (items, doc) => {
							if (doc.rating >= 4) {
								items.push(doc);
							}
							return items;
						},
						on_remove: (items, doc) => {
							const index = items.findIndex((item) => item.id === doc.id);
							if (index !== -1) {
								items.splice(index, 1);
							}
							return items;
						},
					},
				),
			],
		});

		// Create test documents with simple names
		const now = Date.now();
		docs = [
			create_document({
				title: 'doc_a1',
				author: 'author_a',
				tags: ['tag1', 'tag2', 'tag3'],
				category: 'category_a',
				created: new Date(now - 1000 * 60 * 60 * 24 * 10), // 10 days ago
				rating: 4,
				featured: true,
			}),
			create_document({
				title: 'doc_a2',
				author: 'author_b',
				tags: ['tag1', 'tag4'],
				category: 'category_a',
				created: new Date(now - 1000 * 60 * 60 * 24 * 20), // 20 days ago
				rating: 5,
				featured: true,
			}),
			create_document({
				title: 'doc_b1',
				author: 'author_a',
				tags: ['tag2', 'tag5'],
				category: 'category_b',
				created: new Date(now - 1000 * 60 * 60 * 24 * 5), // 5 days ago
				rating: 4,
				featured: false,
			}),
			create_document({
				title: 'doc_c1',
				author: 'author_c',
				tags: ['tag3', 'tag6'],
				category: 'category_c',
				created: new Date(now - 1000 * 60 * 60 * 24 * 30), // 30 days ago
				rating: 3,
				featured: false,
			}),
			create_document({
				title: 'doc_b2',
				author: 'author_c',
				tags: ['tag1', 'tag5'],
				category: 'category_b',
				created: new Date(now - 1000 * 60 * 60 * 24 * 3), // 3 days ago
				rating: 5,
				featured: true,
			}),
		];

		// Add all documents to the collection
		collection.add_many(docs);
	});

	test('basic query operations', () => {
		// Single index direct lookup
		expect(collection.by_optional('by_title', 'doc_a1'.toLowerCase())).toBe(docs[0]);
		expect(collection.by_optional('by_author', 'author_a')).toBeDefined();

		// Multi index direct lookup
		expect(collection.where('by_category', 'category_a')).toHaveLength(2);
		expect(collection.where('by_rating', 5)).toHaveLength(2);
		expect(collection.where('by_featured', 'yes')).toHaveLength(3);

		// Non-existent values
		expect(collection.by_optional('by_title', 'nonexistent')).toBeUndefined();
		expect(collection.where('by_category', 'nonexistent')).toHaveLength(0);
	});

	test('case sensitivity in queries', () => {
		// Case insensitive title lookup (extractor converts to lowercase)
		expect(collection.by_optional('by_title', 'doc_a1'.toLowerCase())).toBe(docs[0]);
		expect(collection.by_optional('by_title', 'DOC_A1'.toLowerCase())).toBe(docs[0]);

		// Case sensitive author lookup (no conversion in extractor)
		expect(collection.by_optional('by_author', 'AUTHOR_A')).toBeUndefined();
		expect(collection.by_optional('by_author', 'author_a')).toBeDefined();
	});

	test('compound queries combining indexes', () => {
		// Find category_a documents by author_a
		const category_a_docs = collection.where('by_category', 'category_a');
		const author_a_category_a_docs = category_a_docs.filter((doc) => doc.author === 'author_a');
		expect(author_a_category_a_docs).toHaveLength(1);
		expect(author_a_category_a_docs[0].title).toBe('doc_a1');

		// Find featured documents with rating 5
		const featured_docs = collection.where('by_featured', 'yes');
		const high_rated_featured = featured_docs.filter((doc) => doc.rating === 5);
		expect(high_rated_featured).toHaveLength(2);
		expect(high_rated_featured.map((d) => d.title)).toContain('doc_a2');
		expect(high_rated_featured.map((d) => d.title)).toContain('doc_b2');
	});

	test('queries with array values', () => {
		// Query by tag (checks if any tag matches)
		const tag1_docs = collection.where('by_tag', 'tag1');
		expect(tag1_docs).toHaveLength(3);
		expect(tag1_docs.map((d) => d.title)).toContain('doc_a1');
		expect(tag1_docs.map((d) => d.title)).toContain('doc_a2');
		expect(tag1_docs.map((d) => d.title)).toContain('doc_b2');

		// Multiple tag intersection (using multiple queries)
		const tag2_docs = collection.where('by_tag', 'tag2');
		const tag2_and_tag3_docs = tag2_docs.filter((doc) => doc.tags.includes('tag3'));
		expect(tag2_and_tag3_docs).toHaveLength(1);
		expect(tag2_and_tag3_docs[0].title).toBe('doc_a1');
	});

	test('derived index queries', () => {
		// Test the featured_recent derived index
		const recent_featured = collection.get_derived('featured_recent');
		expect(recent_featured).toHaveLength(3); // All featured docs

		// Verify order (most recent first)
		expect(recent_featured[0].title).toBe('doc_b2'); // 3 days ago
		expect(recent_featured[1].title).toBe('doc_a1'); // 10 days ago
		expect(recent_featured[2].title).toBe('doc_a2'); // 20 days ago

		// Test the high_rated derived index which should include all docs with rating 4+
		const high_rated = collection.get_derived('high_rated');
		expect(high_rated).toHaveLength(4);
		expect(high_rated.map((d) => d.title).sort()).toEqual(
			['doc_a1', 'doc_a2', 'doc_b1', 'doc_b2'].sort(),
		);
	});

	test('first/latest with multi-index', () => {
		// Get first category_a document
		const first_category_a = collection.first('by_category', 'category_a', 1);
		expect(first_category_a).toHaveLength(1);
		expect(first_category_a[0].title).toBe('doc_a1');

		// Get latest category_b document
		const latest_category_b = collection.latest('by_category', 'category_b', 1);
		expect(latest_category_b).toHaveLength(1);
		expect(latest_category_b[0].title).toBe('doc_b2');
	});

	test('time-based queries', () => {
		// Query by publication year
		const current_year = new Date().getFullYear();
		const this_year_docs = collection.where('by_year', current_year);

		const docs_this_year = collection.all.filter(
			(doc) => doc.created.getFullYear() === current_year,
		).length;
		expect(this_year_docs.length).toBe(docs_this_year);

		// More complex date range query - last 7 days
		const now = Date.now();
		const recent_docs = collection.all.filter(
			(doc) => doc.created.getTime() > now - 1000 * 60 * 60 * 24 * 7,
		);
		expect(recent_docs.map((d) => d.title)).toContain('doc_b1'); // 5 days ago
		expect(recent_docs.map((d) => d.title)).toContain('doc_b2'); // 3 days ago
	});

	test('adding items affects derived queries correctly', () => {
		// Add a new featured document with high rating
		const new_doc = create_document({
			title: 'doc_d1',
			author: 'author_d',
			tags: ['tag7'],
			category: 'category_d',
			created: new Date(), // Now (most recent)
			rating: 5,
			featured: true,
		});

		collection.add(new_doc);

		// Check that it appears at the top of the featured_recent list
		const recent_featured = collection.get_derived('featured_recent');
		expect(recent_featured[0].id).toBe(new_doc.id);

		// Check that it appears in high_rated
		const high_rated = collection.get_derived('high_rated');
		expect(has_item_with_id(high_rated, new_doc)).toBe(true);
	});

	test('removing items updates derived queries', () => {
		// Remove the most recent featured document
		const doc_to_remove = docs[4]; // doc_b2 (most recent featured)

		collection.remove(doc_to_remove.id);

		// Check that featured_recent updates correctly
		const recent_featured = collection.get_derived('featured_recent');
		expect(recent_featured).toHaveLength(2);
		expect(recent_featured[0].title).toBe('doc_a1');
		expect(recent_featured[1].title).toBe('doc_a2');

		// Check that high_rated updates correctly
		const high_rated = collection.get_derived('high_rated');
		expect(high_rated).not.toContain(doc_to_remove);
		expect(high_rated).toHaveLength(3); // Started with 4, removed 1
	});

	test('dynamic ordering of query results', () => {
		// Get all documents and sort by rating (highest first)
		const sorted_by_rating = [...collection.all].sort((a, b) => b.rating - a.rating);
		expect(sorted_by_rating[0].rating).toBe(5);

		// Sort by creation date (newest first)
		const sorted_by_date = [...collection.all].sort(
			(a, b) => b.created.getTime() - a.created.getTime(),
		);
		expect(sorted_by_date[0].title).toBe('doc_b2'); // 3 days ago
	});
});

describe('Indexed_Collection - Search Patterns', () => {
	let collection: Indexed_Collection<Test_Document>;

	beforeEach(() => {
		collection = new Indexed_Collection<Test_Document>({
			indexes: [
				// Word-based index that splits title into words for searching
				create_multi_index('by_word', (doc) => doc.title.toLowerCase().split(/\s+/)),

				// Range-based categorization
				create_multi_index('by_rating_range', (doc) => {
					if (doc.rating <= 2) return 'low';
					if (doc.rating <= 4) return 'medium';
					return 'high';
				}),
			],
		});

		const documents = [
			create_document({
				title: 'alpha beta gamma',
				rating: 5,
			}),
			create_document({
				title: 'alpha delta',
				rating: 4,
			}),
			create_document({
				title: 'beta epsilon',
				rating: 3,
			}),
			create_document({
				title: 'gamma delta',
				rating: 2,
			}),
		];

		collection.add_many(documents);
	});

	test('word-based search', () => {
		// Find documents with "alpha" in title
		const alpha_docs = collection.where('by_word', 'alpha');
		expect(alpha_docs).toHaveLength(2);

		// Find documents with "beta" in title
		const beta_docs = collection.where('by_word', 'beta');
		expect(beta_docs).toHaveLength(2);

		// Find documents with both "alpha" and "beta" (intersection)
		const alpha_beta_docs = alpha_docs.filter((doc) => doc.title.toLowerCase().includes('beta'));
		expect(alpha_beta_docs).toHaveLength(1);
		expect(alpha_beta_docs[0].title).toBe('alpha beta gamma');
	});

	test('range-based categorization', () => {
		// Find high-rated documents
		const high_rated = collection.where('by_rating_range', 'high');
		expect(high_rated).toHaveLength(1);
		expect(high_rated[0].rating).toBe(5);

		// Find medium-rated documents
		const medium_rated = collection.where('by_rating_range', 'medium');
		expect(medium_rated).toHaveLength(2);

		// Find low-rated documents
		const low_rated = collection.where('by_rating_range', 'low');
		expect(low_rated).toHaveLength(1);
		expect(low_rated[0].rating).toBe(2);
	});
});
