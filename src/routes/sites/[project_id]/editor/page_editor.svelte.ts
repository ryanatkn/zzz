import {goto} from '$app/navigation';

import {projects_context, type Page, type Project} from '../../projects.svelte.js';

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
const parse_markdown = (text: string): string => {
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
	/** Project ID being edited. */
	readonly project_id: string;

	/** Page ID being edited. */
	readonly page_id: string;

	/** Whether this is a new page. */
	readonly is_new_page: boolean;

	/** Get the projects instance from context */
	readonly projects = projects_context.get();

	/** The current project. */
	readonly project: Project | null = $derived(
		this.projects.projects.find((p) => p.id === this.project_id) || null,
	);

	/** The current page. */
	readonly current_page: Page | null = $derived.by(() =>
		!this.is_new_page ? this.project?.pages.find((p) => p.id === this.page_id) || null : null,
	);

	/** Page title form field. */
	title: string = $state('');

	/** Page path form field. */
	path: string = $state('/');

	/** Page content form field. */
	content: string = $state('# New Page\n\nAdd your content here.');

	/** UI state for sidebar visibility. */
	sidebar_visible: boolean = $state(true);

	/** UI state for view mode. */
	view_mode: 'split' | 'fullscreen' = $state('split');

	/** Safely formatted content for preview. */
	readonly formatted_content = $derived.by(() => {
		return parse_markdown(this.content);
	});

	/**
	 * Creates a new Page_Editor instance.
	 */
	constructor(project_id: string, page_id: string) {
		this.project_id = project_id;
		this.page_id = page_id;
		this.is_new_page = page_id === 'new';

		$effect(() => {
			if (this.current_page) {
				this.title = this.current_page.title;
				this.path = this.current_page.path;
				this.content = this.current_page.content;
			}
		});
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
		const timestamp = new Date().toISOString();

		if (this.is_new_page) {
			// Create new page
			const new_page: Page = {
				id: 'page_' + Date.now(),
				title: this.title,
				path: formatted_path,
				content: this.content,
				created_at: timestamp,
				updated_at: timestamp,
			};

			this.projects.add_page(this.project_id, new_page);
			void goto(`/sites/${this.project_id}`);
		} else if (this.current_page) {
			// Update existing page
			this.projects.update_page(this.project_id, {
				...this.current_page,
				title: this.title,
				path: formatted_path,
				content: this.content,
				updated_at: timestamp,
			});
			void goto(`/sites/${this.project_id}`);
		}
	}

	/**
	 * Toggle sidebar visibility.
	 */
	toggle_sidebar(): void {
		this.sidebar_visible = !this.sidebar_visible;
	}

	/**
	 * Toggle view mode between split and fullscreen.
	 */
	toggle_view_mode(): void {
		this.view_mode = this.view_mode === 'split' ? 'fullscreen' : 'split';
	}
}
