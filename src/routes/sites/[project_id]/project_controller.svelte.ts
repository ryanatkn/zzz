import {goto} from '$app/navigation';
import {projects_context, type Project} from '../projects.svelte.js';

/**
 * Controls project management functionality.
 */
export class Project_Controller {
	/** Project ID. */
	readonly project_id: string;

	/** Get the projects instance from context */
	readonly projects = projects_context.get();

	/** Current project data. */
	readonly project: Project | null = $derived(
		this.projects.projects.find((p) => p.id === this.project_id) || null,
	);

	/** Active tab in the project interface. */
	active_tab: 'pages' | 'domains' | 'settings' = $state('pages');

	/** Whether the project is in editing mode. */
	editing_project: boolean = $state(false);

	/** Edited project name field. */
	edited_name: string = $state('');

	/** Edited project description field. */
	edited_description: string = $state('');

	/**
	 * Creates a Project_Controller instance.
	 */
	constructor(project_id: string) {
		this.project_id = project_id;

		// Initialize edit form when editing starts
		$effect(() => {
			if (this.editing_project && this.project) {
				this.edited_name = this.project.name;
				this.edited_description = this.project.description;
			}
		});

		// If project isn't found, redirect back to projects list
		$effect(() => {
			if (!this.project && this.project_id) {
				void goto('/sites');
			}
		});
	}

	/**
	 * Save project details.
	 */
	save_project_details(): void {
		if (this.project && this.edited_name.trim()) {
			this.projects.update_project({
				...this.project,
				name: this.edited_name,
				description: this.edited_description,
				updated_at: new Date().toISOString(),
			});
			this.editing_project = false;
		}
	}

	/**
	 * Delete a page from the project.
	 */
	delete_project_page(page_id: string): void {
		// eslint-disable-next-line no-alert
		if (confirm('Are you sure you want to delete this page? This action cannot be undone.')) {
			this.projects.delete_page(this.project_id, page_id);
		}
	}

	/**
	 * Delete the entire project.
	 */
	delete_current_project(): void {
		if (
			// eslint-disable-next-line no-alert
			confirm('Are you sure you want to delete this project? All pages and settings will be lost.')
		) {
			this.projects.delete_project(this.project_id);
			void goto('/sites');
		}
	}
}
