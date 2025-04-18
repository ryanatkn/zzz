import {goto} from '$app/navigation';

import {get_datetime_now} from '$lib/zod_helpers.js';
import {projects_context, type Project, type Projects} from './projects.svelte.js';

/**
 * Controller for managing a specific project and its state.
 */
export class Project_Controller {
	/** Projects service instance. */
	readonly projects: Projects;

	/** Edited project name for the form. */
	edited_name = $state('');

	/** Edited project description for the form. */
	edited_description = $state('');

	/** State for project editing UI. */
	editing_project = $state(false);

	/** Whether the form has unsaved changes. */
	has_changes = $derived(
		this.project &&
			(this.edited_name !== this.project.name ||
				this.edited_description !== this.project.description),
	);

	/**
	 * The current project derived from the projects service.
	 */
	get project(): Project | null {
		return this.projects.current_project;
	}

	/**
	 * Creates a new Project_Controller.
	 */
	constructor(
		public project_id: string,
		projects?: Projects,
	) {
		this.projects = projects || projects_context.get();
		this.reset_form();
	}

	/**
	 * Reset form to match current project values.
	 */
	reset_form(): void {
		if (this.project) {
			this.edited_name = this.project.name;
			this.edited_description = this.project.description;
		}
	}

	/**
	 * Save edited project details.
	 */
	save_project_details(): void {
		if (!this.project) return;

		if (!this.edited_name.trim()) {
			// eslint-disable-next-line no-alert
			alert('Project name is required.');
			return;
		}

		this.projects.update_project({
			...this.project,
			name: this.edited_name,
			description: this.edited_description,
			updated: get_datetime_now(),
		});

		this.editing_project = false;
	}

	/**
	 * Delete the current project.
	 */
	delete_current_project(): void {
		if (!this.project) return;

		// eslint-disable-next-line no-alert
		const confirmed = confirm(
			'Are you sure you want to delete this project? This action cannot be undone.',
		);

		if (confirmed && this.projects.current_project_id) {
			this.projects.delete_project(this.projects.current_project_id);
			void goto('/projects');
		}
	}

	/**
	 * Delete a page from the current project.
	 */
	delete_project_page(page_id: string): void {
		if (!this.projects.current_project_id) return;

		// eslint-disable-next-line no-alert
		const confirmed = confirm(
			'Are you sure you want to delete this page? This action cannot be undone.',
		);

		if (confirmed) {
			this.projects.delete_page(this.projects.current_project_id, page_id);
		}
	}

	/**
	 * Delete a domain from the current project.
	 */
	delete_project_domain(domain_id: string): void {
		if (!this.projects.current_project_id) return;

		// eslint-disable-next-line no-alert
		const confirmed = confirm(
			'Are you sure you want to delete this domain? This action cannot be undone.',
		);

		if (confirmed) {
			this.projects.delete_domain(this.projects.current_project_id, domain_id);
		}
	}

	/**
	 * Create a new blank page and navigate to it.
	 */
	create_new_page(): void {
		if (!this.project) return;

		const created = get_datetime_now();
		const page_id = 'page_' + Date.now();

		this.projects.add_page(this.project_id, {
			id: page_id,
			title: 'New Page',
			path: '/new-page',
			content: '# New Page\n\nAdd your content here.',
			created,
			updated: created,
		});

		void goto(`/projects/${this.project_id}/pages/${page_id}`);
	}

	/**
	 * Create a new domain and navigate to it.
	 */
	create_new_domain(): void {
		if (!this.project) return;

		const domain_id = 'dom_' + Date.now();
		const created = get_datetime_now();

		this.projects.add_domain(this.project_id, {
			id: domain_id,
			name: '',
			status: 'pending',
			ssl: false,
			created,
			updated: created,
		});

		void goto(`/projects/${this.project_id}/domains/${domain_id}`);
	}
}
