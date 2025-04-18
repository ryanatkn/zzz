import {goto} from '$app/navigation';

import {get_datetime_now} from '$lib/zod_helpers.js';
import {projects_context, type Page, type Project, type Projects} from './projects.svelte.js';

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
export class Page_Editor {
	/** Projects service instance. */
	readonly projects: Projects;

	/** Page title form field. */
	title: string = $state('');

	/** Page path form field. */
	path: string = $state('/');

	/** Page content form field. */
	content: string = $state('# New Page\n\nAdd your content here.');

	/** Whether the form has been initialized. */
	#initialized: boolean = $state(false);

	/** Whether the form has unsaved changes. */
	has_changes = $derived(
		this.#initialized &&
			(this.is_new_page ||
				(this.current_page &&
					(this.title !== this.current_page.title ||
						this.path !== this.current_page.path ||
						this.content !== this.current_page.content))),
	);

	/** Whether this is a new page. */
	get is_new_page(): boolean {
		return this.page_id === 'new';
	}

	/** The current project. */
	get project(): Project | null {
		return this.projects.current_project;
	}

	/** The current page. */
	get current_page(): Page | null {
		return !this.is_new_page ? this.projects.current_page : null;
	}

	/** Safely formatted content for preview. */
	get formatted_content(): string {
		return render_markdown(this.content);
	}

	/**
	 * Creates a new Page_Editor instance.
	 */
	constructor(
		public project_id: string,
		public page_id: string,
		projects?: Projects,
	) {
		this.projects = projects || projects_context.get();

		if ((this.project || this.is_new_page) && !this.#initialized) {
			this.init_form();
			this.#initialized = true;
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
			this.title = '';
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
		const created = get_datetime_now();

		if (this.is_new_page) {
			// Create new page
			const new_page: Page = {
				id: 'page_' + Date.now(),
				title: this.title,
				path: formatted_path,
				content: this.content,
				created,
				updated: created,
			};

			this.projects.add_page(this.project_id, new_page);
			void goto(`/projects/${this.project_id}/pages`);
		} else if (this.current_page) {
			// Update existing page
			this.projects.update_page(this.project_id, {
				...this.current_page,
				title: this.title,
				path: formatted_path,
				content: this.content,
				updated: created,
			});
			void goto(`/projects/${this.project_id}/pages`);
		}
	}
}
