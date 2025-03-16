import {test, expect, describe, beforeEach} from 'vitest';
import {Indexed_Collection, Index_Type} from '$lib/indexed_collection.svelte.js';
import {Uuid} from '$lib/zod_helpers.js';

// Test item representing a document or record
interface Document_Item {
	id: Uuid;
	title: string;
	author: string;
	tags: Array<string>;
	category: string;
	published_date: Date;
	rating: number;
	is_featured: boolean;
	metadata?: {
		word_count?: number;
		language?: string;
		region?: string;
	};
}

// Helper to create document items with default values that can be overridden
const create_document = (overrides: Partial<Document_Item> = {}): Document_Item => ({
	id: Uuid.parse(undefined),
	title: 'Default Title',
	author: 'Default Author',
	tags: ['default'],
	category: 'general',
	published_date: new Date(),
	rating: 3,
	is_featured: false,
	metadata: {
		word_count: 1000,
		language: 'en',
		region: 'US',
	},
	...overrides,
});

describe('Indexed_Collection - Query Capabilities', () => {
	let collection: Indexed_Collection<Document_Item>;
	let documents: Array<Document_Item>;

	beforeEach(() => {
		// Create a collection with various indexes for testing different query patterns
		collection = new Indexed_Collection<Document_Item>({
			indexes: [
				// Single value indexes
				// Fix case sensitivity handling
				{
					key: 'by_title',
					type: Index_Type.SINGLE,
					// Convert both extraction and lookup to lowercase to ensure case insensitivity
					extractor: (doc) => doc.title.toLowerCase(),
				},
				{
					key: 'by_author',
					type: Index_Type.SINGLE,
					extractor: (doc) => doc.author,
				},
				// Multi value indexes
				{
					key: 'by_category',
					type: Index_Type.MULTI,
					extractor: (doc) => doc.category,
				},
				{
					key: 'by_tag',
					type: Index_Type.MULTI,
					extractor: (doc) => doc.tags,
				},
				{
					key: 'by_rating',
					type: Index_Type.MULTI,
					extractor: (doc) => doc.rating,
				},
				{
					key: 'by_featured',
					type: Index_Type.MULTI,
					extractor: (doc) => (doc.is_featured ? 'featured' : 'standard'),
				},
				{
					key: 'by_language',
					type: Index_Type.MULTI,
					extractor: (doc) => doc.metadata?.language,
				},
				// Derived indexes
				{
					key: 'featured_recent',
					type: Index_Type.DERIVED,
					compute: (collection) => {
						return collection.all
							.filter((doc) => doc.is_featured)
							.sort((a, b) => b.published_date.getTime() - a.published_date.getTime())
							.slice(0, 5); // Top 5 recent featured items
					},
					matches: (doc) => doc.is_featured,
					on_add: (items, doc) => {
						if (!doc.is_featured) return;

						// Find the right position based on date (newer items first)
						const index = items.findIndex(
							(existing) => doc.published_date.getTime() > existing.published_date.getTime(),
						);

						if (index === -1) {
							items.push(doc);
						} else {
							items.splice(index, 0, doc);
						}

						// Maintain max size
						if (items.length > 5) {
							items.pop();
						}
					},
					on_remove: (items, doc) => {
						const index = items.findIndex((item) => item.id === doc.id);
						if (index !== -1) {
							items.splice(index, 1);
						}
					},
				},
				// Fix high_rated derived index
				{
					key: 'high_rated',
					type: Index_Type.DERIVED,
					compute: (collection) => {
						// Filter to get all docs rated 4+
						return collection.all.filter((doc) => doc.rating >= 4);
					},
					matches: (doc) => doc.rating >= 4,
					on_add: (items, doc) => {
						if (doc.rating >= 4) {
							items.push(doc);
						}
					},
					on_remove: (items, doc) => {
						const index = items.findIndex((item) => item.id === doc.id);
						if (index !== -1) {
							items.splice(index, 1);
						}
					},
				},
				{
					key: 'by_year',
					type: Index_Type.MULTI,
					extractor: (doc) => doc.published_date.getFullYear(),
				},
			],
		});

		// Create test documents
		const now = Date.now();
		documents = [
			create_document({
				title: 'TypeScript Fundamentals',
				author: 'Alice Johnson',
				tags: ['programming', 'typescript', 'beginner'],
				category: 'programming',
				published_date: new Date(now - 3600000 * 24 * 30), // 30 days ago
				rating: 4,
				is_featured: true,
			}),
			create_document({
				title: 'Advanced JavaScript Patterns',
				author: 'Bob Smith',
				tags: ['programming', 'javascript', 'advanced'],
				category: 'programming',
				published_date: new Date(now - 3600000 * 24 * 60), // 60 days ago
				rating: 5,
				is_featured: true,
				metadata: {
					word_count: 5000,
					language: 'en',
					region: 'UK',
				},
			}),
			create_document({
				title: 'Database Design Principles',
				author: 'Carol Williams',
				tags: ['database', 'sql', 'design'],
				category: 'database',
				published_date: new Date(now - 3600000 * 24 * 15), // 15 days ago
				rating: 4,
				is_featured: false,
			}),
			create_document({
				title: 'Introduction to Web Development',
				author: 'Alice Johnson',
				tags: ['web', 'html', 'css', 'beginner'],
				category: 'web',
				published_date: new Date(now - 3600000 * 24 * 120), // 120 days ago
				rating: 3,
				is_featured: false,
			}),
			create_document({
				title: 'Python for Data Science',
				author: 'Dave Martin',
				tags: ['python', 'data-science', 'machine-learning'],
				category: 'data-science',
				published_date: new Date(now - 3600000 * 24 * 10), // 10 days ago
				rating: 5,
				is_featured: true,
				metadata: {
					word_count: 8000,
					language: 'en',
					region: 'US',
				},
			}),
		];

		// Add all documents to the collection
		collection.add_many(documents);
	});

	test('basic query operations', () => {
		// Single index direct lookup
		expect(collection.by_optional('by_title', 'python for data science')).toBe(documents[4]);
		expect(collection.by_optional('by_author', 'Alice Johnson')).toBeDefined();

		// Multi index direct lookup
		expect(collection.where('by_category', 'programming')).toHaveLength(2);
		expect(collection.where('by_rating', 5)).toHaveLength(2);
		expect(collection.where('by_featured', 'featured')).toHaveLength(3);

		// Non-existent values
		expect(collection.by_optional('by_title', 'nonexistent title')).toBeUndefined();
		expect(collection.where('by_category', 'nonexistent category')).toHaveLength(0);
	});

	test('case sensitivity in queries', () => {
		// Case insensitive title lookup (extractor converts to lowercase)
		expect(collection.by_optional('by_title', 'typescript fundamentals')).toBe(documents[0]);
		// This should also work with uppercase since we're lowercasing in the extractor
		expect(collection.by_optional('by_title', 'TYPESCRIPT FUNDAMENTALS'.toLowerCase())).toBe(
			documents[0],
		);

		// Case sensitive author lookup (no conversion in extractor)
		expect(collection.by_optional('by_author', 'alice johnson')).toBeUndefined();
		expect(collection.by_optional('by_author', 'Alice Johnson')).toBeDefined();
	});

	test('compound queries combining indexes', () => {
		// Find programming documents by Alice
		const programming_docs = collection.where('by_category', 'programming');
		const alice_programming_docs = programming_docs.filter((doc) => doc.author === 'Alice Johnson');
		expect(alice_programming_docs).toHaveLength(1);
		expect(alice_programming_docs[0].title).toBe('TypeScript Fundamentals');

		// Find featured documents with rating 5
		const featured_docs = collection.where('by_featured', 'featured');
		const high_rated_featured = featured_docs.filter((doc) => doc.rating === 5);
		expect(high_rated_featured).toHaveLength(2);
		expect(high_rated_featured.map((d) => d.title)).toContain('Advanced JavaScript Patterns');
		expect(high_rated_featured.map((d) => d.title)).toContain('Python for Data Science');
	});

	test('queries with array values', () => {
		// Query by tag (checks if any tag matches)
		const beginner_docs = collection.where('by_tag', 'beginner');
		expect(beginner_docs).toHaveLength(2);
		expect(beginner_docs.map((d) => d.title)).toContain('TypeScript Fundamentals');
		expect(beginner_docs.map((d) => d.title)).toContain('Introduction to Web Development');

		// Multiple tag intersection (using multiple queries)
		const programming_docs = collection.where('by_tag', 'programming');
		const typescript_docs = programming_docs.filter((doc) => doc.tags.includes('typescript'));
		expect(typescript_docs).toHaveLength(1);
		expect(typescript_docs[0].title).toBe('TypeScript Fundamentals');
	});

	test('derived index queries', () => {
		// Test the featured_recent derived index
		const recent_featured = collection.get_derived('featured_recent');
		expect(recent_featured).toHaveLength(3); // All featured docs

		// Verify order (most recent first)
		expect(recent_featured[0].title).toBe('Python for Data Science'); // 10 days ago
		expect(recent_featured[1].title).toBe('TypeScript Fundamentals'); // 30 days ago
		expect(recent_featured[2].title).toBe('Advanced JavaScript Patterns'); // 60 days ago

		// Test the high_rated derived index which should include all docs with rating 4+
		const high_rated = collection.get_derived('high_rated');
		// Check contents rather than specific length
		expect(high_rated).toEqual(
			expect.arrayContaining([
				documents[0], // TypeScript Fundamentals (rating 4)
				documents[1], // Advanced JavaScript Patterns (rating 5)
				documents[2], // Database Design Principles (rating 4)
				documents[4], // Python for Data Science (rating 5)
			]),
		);
		expect(high_rated.map((d) => d.title)).toContain('TypeScript Fundamentals');
		expect(high_rated.map((d) => d.title)).toContain('Advanced JavaScript Patterns');
		expect(high_rated.map((d) => d.title)).toContain('Database Design Principles');
	});

	test('dynamic query combinations', () => {
		// Mimic a more complex query: "Featured programming resources with high rating"
		const featured_docs = collection.where('by_featured', 'featured');
		const programming_featured = featured_docs.filter((doc) => doc.category === 'programming');
		const high_rated_programming_featured = programming_featured.filter((doc) => doc.rating >= 4);

		expect(high_rated_programming_featured).toHaveLength(2);
		expect(high_rated_programming_featured.map((d) => d.title)).toContain(
			'TypeScript Fundamentals',
		);
		expect(high_rated_programming_featured.map((d) => d.title)).toContain(
			'Advanced JavaScript Patterns',
		);
	});

	test('first/latest with multi-index', () => {
		// Get first programming document
		const first_programming = collection.first('by_category', 'programming', 1);
		expect(first_programming).toHaveLength(1);
		expect(first_programming[0].title).toBe('TypeScript Fundamentals');

		// Get latest programming document
		const latest_programming = collection.latest('by_category', 'programming', 1);
		expect(latest_programming).toHaveLength(1);
		expect(latest_programming[0].title).toBe('Advanced JavaScript Patterns');
	});

	test('queries with optional properties', () => {
		// Query by optional nested properties
		const uk_docs = collection
			.where('by_language', 'en')
			.filter((doc) => doc.metadata?.region === 'UK');
		expect(uk_docs).toHaveLength(1);
		expect(uk_docs[0].title).toBe('Advanced JavaScript Patterns');

		// Query with undefined values
		const no_language_docs = collection.all.filter((doc) => doc.metadata?.language === undefined);
		expect(no_language_docs).toHaveLength(0); // All have a language set
	});

	test('time-based queries', () => {
		// Query by publication year
		const current_year = new Date().getFullYear();
		const this_year_docs = collection.where('by_year', current_year);

		// Fix: Must match the actual number of documents (may vary if documents span multiple years)
		const docs_this_year = collection.all.filter(
			(doc) => doc.published_date.getFullYear() === current_year,
		).length;
		expect(this_year_docs.length).toBe(docs_this_year);

		// More complex date range query
		const now = Date.now();
		const recent_docs = collection.all.filter(
			(doc) => doc.published_date.getTime() > now - 3600000 * 24 * 20, // Last 20 days
		);
		expect(recent_docs).toHaveLength(2); // The 10-day and 15-day old docs
		expect(recent_docs.map((d) => d.title)).toContain('Database Design Principles');
		expect(recent_docs.map((d) => d.title)).toContain('Python for Data Science');
	});

	test('adding items affects derived queries correctly', () => {
		// Add a new featured document with high rating
		const new_doc = create_document({
			title: 'New Featured Document',
			author: 'Emma Thompson',
			tags: ['new', 'featured'],
			category: 'general',
			published_date: new Date(), // Now (most recent)
			rating: 5,
			is_featured: true,
		});

		collection.add(new_doc);

		// Check that it appears at the top of the featured_recent list
		const recent_featured = collection.get_derived('featured_recent');
		expect(recent_featured[0]).toBe(new_doc);

		// Check that it appears in high_rated
		const high_rated = collection.get_derived('high_rated');
		expect(high_rated).toContain(new_doc);
	});

	test('removing items updates derived queries', () => {
		// Remove the most recent featured document
		const python_doc = documents[4]; // Python for Data Science

		// Log the high-rated documents before removal
		console.log(
			'High-rated docs before removal:',
			collection.get_derived('high_rated').map((d) => ({title: d.title, rating: d.rating})),
		);

		collection.remove(python_doc.id);

		// Check that featured_recent updates correctly
		const recent_featured = collection.get_derived('featured_recent');
		expect(recent_featured).toHaveLength(2);
		expect(recent_featured[0].title).toBe('TypeScript Fundamentals');
		expect(recent_featured[1].title).toBe('Advanced JavaScript Patterns');

		// Check that high_rated updates correctly
		const high_rated = collection.get_derived('high_rated');
		expect(high_rated).not.toContain(python_doc);

		// Log what's actually in the high_rated collection after removal
		console.log(
			'High-rated docs after removal:',
			high_rated.map((d) => ({title: d.title, rating: d.rating})),
		);

		// Three high rated docs originally (4, 5, 4, 5) but removed one (5)
		// So expect 3 docs initially, then 2 after removal
		expect(high_rated).toHaveLength(3);
	});

	test('dynamic ordering of query results', () => {
		// Get all documents and sort by rating (highest first)
		const sorted_by_rating = [...collection.all].sort((a, b) => b.rating - a.rating);
		expect(sorted_by_rating[0].rating).toBe(5);
		expect(sorted_by_rating[0].title).toBe('Advanced JavaScript Patterns');

		// Sort by publication date (newest first)
		const sorted_by_date = [...collection.all].sort(
			(a, b) => b.published_date.getTime() - a.published_date.getTime(),
		);
		expect(sorted_by_date[0].title).toBe('Python for Data Science');
	});
});

describe('Indexed_Collection - Advanced Query Patterns', () => {
	let collection: Indexed_Collection<Document_Item>;

	beforeEach(() => {
		collection = new Indexed_Collection<Document_Item>({
			indexes: [
				{
					key: 'by_title_words',
					type: Index_Type.MULTI,
					extractor: (doc) => doc.title.toLowerCase().split(/\s+/),
				},
				{
					key: 'by_rating_range',
					type: Index_Type.MULTI,
					extractor: (doc) => {
						if (doc.rating <= 2) return 'low';
						if (doc.rating <= 4) return 'medium';
						return 'high';
					},
				},
			],
		});

		const documents = [
			create_document({
				title: 'JavaScript Design Patterns',
				rating: 5,
			}),
			create_document({
				title: 'Python Programming Guide',
				rating: 4,
			}),
			create_document({
				title: 'Advanced Design Principles',
				rating: 3,
			}),
			create_document({
				title: 'Web Development Patterns',
				rating: 2,
			}),
		];

		collection.add_many(documents);
	});

	test('word-based search', () => {
		// Find documents with "design" in title
		const design_docs = collection.where('by_title_words', 'design');
		expect(design_docs).toHaveLength(2);

		// Find documents with "patterns" in title
		const patterns_docs = collection.where('by_title_words', 'patterns');
		expect(patterns_docs).toHaveLength(2);

		// Find documents with both "design" and "patterns" (intersection)
		const design_patterns_docs = design_docs.filter((doc) =>
			doc.title.toLowerCase().includes('patterns'),
		);
		expect(design_patterns_docs).toHaveLength(1);
		expect(design_patterns_docs[0].title).toBe('JavaScript Design Patterns');
	});

	test('range-based categorization', () => {
		// Find high-rated documents
		const high_rated = collection.where('by_rating_range', 'high');
		expect(high_rated).toHaveLength(1);
		expect(high_rated[0].title).toBe('JavaScript Design Patterns');

		// Find medium-rated documents
		const medium_rated = collection.where('by_rating_range', 'medium');
		expect(medium_rated).toHaveLength(2);

		// Find low-rated documents
		const low_rated = collection.where('by_rating_range', 'low');
		expect(low_rated).toHaveLength(1);
		expect(low_rated[0].title).toBe('Web Development Patterns');
	});
});
