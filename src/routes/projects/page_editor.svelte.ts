import {z} from 'zod';
import {goto} from '$app/navigation';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Page_Editor_Json} from './projects_schema.js';
import {get_datetime_now, type Uuid} from '$lib/zod_helpers.js';
import {Page} from './page.svelte.js';
import type {Projects} from './projects.svelte.js';
import {base} from '$app/paths';

export interface Page_Editor_Options extends Cell_Options<typeof Page_Editor_Json> {
	projects: Projects;
}

/**
 * Simple sanitization function to prevent XSS attacks.
 * This is a basic implementation and should be replaced with a proper sanitization library in production.
 */
const sanitize_html = (html: string): string => {
	// Remove script tags and inline event handlers
	return html
		.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
		.replace(/on\w+="[^"]*"/gi, '')
		.replace(/on\w+='[^']*'/gi, '')
		.replace(/on\w+=\S+/gi, '');
};

/**
 * Simple markdown parser for basic formatting.
 */
const render_markdown = (text: string): string => {
	// Split content by double newlines to identify paragraphs
	const paragraphs = text.split(/\n\n+/);

	// Process each paragraph
	const formatted = paragraphs
		.map((paragraph) => {
			// Trim the paragraph
			let p = paragraph.trim();
			if (!p) return '';

			// Basic heading detection
			if (p.startsWith('# ')) {
				return `<h1>${sanitize_html(p.substring(2))}</h1>`;
			} else if (p.startsWith('## ')) {
				return `<h2>${sanitize_html(p.substring(3))}</h2>`;
			} else if (p.startsWith('### ')) {
				return `<h3>${sanitize_html(p.substring(4))}</h3>`;
			}

			// Basic list detection
			if (p.includes('\n- ')) {
				const items = p.split('\n- ');
				const list_items = items
					.slice(1)
					.map((item) => `<li>${sanitize_html(item)}</li>`)
					.join('');

				if (items[0].trim() === '') {
					return `<ul>${list_items}</ul>`;
				} else {
					return `<p>${sanitize_html(items[0])}</p><ul>${list_items}</ul>`;
				}
			}

			// Bold text
			p = p.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');

			// Italic text
			p = p.replace(/\*(.*?)\*/g, '<em>$1</em>');

			// Regular paragraph
			return `<p>${sanitize_html(p)}</p>`;
		})
		.join('');

	return formatted;
};

/**
 * Manages page editor functionality.
 */
export class Page_Editor extends Cell<typeof Page_Editor_Json> {
	project_id: Uuid = $state()!;
	page_id: Uuid = $state()!;
	title: string = $state()!;
	path: string = $state()!;
	content: string = $state()!;
	is_initialized: boolean = $state()!;

	/** Projects service instance. */
	readonly projects: Projects;

	/** Whether the form has unsaved changes. */
	has_changes = $derived.by(
		() =>
			this.is_initialized &&
			(this.is_new_page ||
				(this.current_page &&
					(this.title !== this.current_page.title ||
						this.path !== this.current_page.path ||
						this.content !== this.current_page.content))),
	);

	/** Whether this is a new page. */
	readonly is_new_page = $derived(this.page_id === 'new');

	/** The current project. */
	readonly project = $derived.by(() => this.projects.current_project);

	/** The current page. */
	readonly current_page = $derived.by(() => {
		if (this.is_new_page) return null;
		return this.project?.pages.find((p) => p.id === this.page_id) || null;
	});

	/** Safely formatted content for preview. */
	readonly formatted_content = $derived(render_markdown(this.content));

	/**
	 * Creates a new Page_Editor instance.
	 */
	constructor(options: Page_Editor_Options) {
		super(Page_Editor_Json, options);

		this.projects = options.projects;

		this.init();

		// TODO BLOCK remove/refactor
		// Initialize form values after construction
		if (!this.is_initialized) {
			this.init_form();
			this.is_initialized = true;
		}
	}

	/**
	 * Initialize form fields based on current page or default values
	 */
	init_form(): void {
		if (this.current_page) {
			this.title = this.current_page.title;
			this.path = this.current_page.path;
			this.content = this.current_page.content;
		} else {
			// Handle default values for new pages
			this.title = 'New Page';
			this.path = '/';
			this.content = '# New Page\n\nAdd your content here.';
		}
	}

	/**
	 * Save the current page.
	 */
	save_page(): void {
		if (!this.project) return;

		if (!this.title.trim() || !this.path.trim()) {
			// eslint-disable-next-line no-alert
			alert('Title and path are required.');
			return;
		}

		// Ensure path starts with /
		const formatted_path = this.path.startsWith('/') ? this.path : `/${this.path}`;
		const now = get_datetime_now();

		if (this.is_new_page) {
			// Create new page
			const page = new Page({
				zzz: this.zzz,
				json: {
					title: this.title,
					path: formatted_path,
					content: this.content,
					created: now,
					updated: now,
				},
			});

			this.projects.add_page(this.project_id, page);
			void goto(`${base}/projects/${this.project_id}/pages`);
		} else if (this.current_page) {
			// Update existing page
			this.current_page.title = this.title;
			this.current_page.path = formatted_path;
			this.current_page.content = this.content;
			this.current_page.updated = now;

			void goto(`${base}/projects/${this.project_id}/pages`);
		}
	}
}

export const Page_Editor_Schema = z.instanceof(Page_Editor);
