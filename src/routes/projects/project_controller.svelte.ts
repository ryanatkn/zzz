import {z} from 'zod';
import {goto} from '$app/navigation';
import {base} from '$app/paths';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Project_Controller_Json} from './projects_schema.js';
import {get_datetime_now, create_uuid, type Uuid} from '$lib/zod_helpers.js';
import {Domain} from './domain.svelte.js';
import {Page} from './page.svelte.js';
import {Projects} from './projects.svelte.js';
import {get_unique_name} from '$lib/helpers.js';

export interface Project_Controller_Options extends Cell_Options<typeof Project_Controller_Json> {
	projects: Projects;
}

/**
 * Controller for managing project details and operations.
 */
export class Project_Controller extends Cell<typeof Project_Controller_Json> {
	project_id: Uuid = $state()!;
	edited_name: string = $state()!;
	edited_description: string = $state()!;
	editing_project: boolean = $state()!;

	/** Projects service instance. */
	readonly projects: Projects;

	/** Whether the form has unsaved changes. */
	has_changes = $derived.by(
		() =>
			this.project &&
			(this.edited_name !== this.project.name ||
				this.edited_description !== this.project.description),
	);

	/** The current project. */
	readonly project = $derived.by(() => this.projects.current_project);

	/**
	 * Creates a new Project_Controller instance.
	 */
	constructor(options: Project_Controller_Options) {
		super(Project_Controller_Json, options);

		this.projects = options.projects;

		this.init();

		// TODO BLOCK remove/refactor
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

		this.project.name = this.edited_name;
		this.project.description = this.edited_description;
		this.project.updated = get_datetime_now();

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

		if (confirmed) {
			this.projects.delete_project(this.project_id);
			void goto('/projects');
		}
	}

	/**
	 * Delete a page from the current project.
	 */
	delete_project_page(page_id: Uuid): void {
		if (!this.project) return;

		// eslint-disable-next-line no-alert
		const confirmed = confirm(
			'Are you sure you want to delete this page? This action cannot be undone.',
		);

		if (confirmed) {
			this.project.delete_page(page_id);
		}
	}

	/**
	 * Create a new blank page and navigate to it.
	 */
	create_new_page(): void {
		if (!this.project) return;

		// Generate a unique page name within this project
		const base_title = 'New Page';
		const existing_titles = this.project.pages.map((p) => p.title);
		const unique_title = get_unique_name(base_title, new Set(existing_titles));

		const page_id = create_uuid();
		const created = get_datetime_now();

		const page = new Page({
			zzz: this.zzz,
			json: {
				id: page_id,
				title: unique_title,
				path: '/new-page',
				content: `# ${unique_title}\n\nAdd your content here.`,
				created,
				updated: created,
			},
		});

		this.project.add_page(page);
		void goto(`${base}/projects/${this.project_id}/pages/${page_id}`);
	}

	/**
	 * Create a new domain and navigate to it.
	 */
	create_new_domain(): void {
		if (!this.project) return;

		const domain_id = create_uuid();
		const created = get_datetime_now();

		const domain = new Domain({
			zzz: this.zzz,
			json: {
				id: domain_id,
				name: '',
				status: 'pending',
				ssl: false,
				created,
				updated: created,
			},
		});

		this.project.add_domain(domain);
		void goto(`${base}/projects/${this.project_id}/domains/${domain_id}`);
	}
}

export const Project_Controller_Schema = z.instanceof(Project_Controller);
