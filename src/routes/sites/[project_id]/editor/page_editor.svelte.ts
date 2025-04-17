import {goto} from '$app/navigation';

import {
	projects_store,
	add_page,
	update_page,
	type Page,
	type Project,
} from '../../sites.svelte.js';

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

	/** The current project. */
	readonly project: Project | null = $derived(
		projects_store.projects.find((p) => p.id === this.project_id) || null,
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

	/** Simple content formatter for preview. */
	readonly formatted_content = $derived(() => {
		// Split content by double newlines to identify paragraphs
		const paragraphs = this.content.split(/\n\n+/);

		// Process each paragraph
		return paragraphs
			.map((paragraph) => {
				// Basic heading detection
				if (paragraph.startsWith('# ')) {
					return `<h1>${paragraph.substring(2)}</h1>`;
				} else if (paragraph.startsWith('## ')) {
					return `<h2>${paragraph.substring(3)}</h2>`;
				} else if (paragraph.startsWith('### ')) {
					return `<h3>${paragraph.substring(4)}</h3>`;
				}

				// Regular paragraph
				return `<p>${paragraph}</p>`;
			})
			.join('');
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

			add_page(this.project_id, new_page);
			void goto(`/sites/${this.project_id}`);
		} else if (this.current_page) {
			// Update existing page
			update_page(this.project_id, {
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
