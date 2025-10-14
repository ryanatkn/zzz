// @slop Claude Opus 4

import {z} from 'zod';
import {goto} from '$app/navigation';
import {resolve} from '$app/paths';

import {create_uuid, get_datetime_now, type Uuid} from '$lib/zod_helpers.js';
import {Repo} from '$routes/projects/repo.svelte.js';
import type {Repo_Checkout} from '$routes/projects/projects_schema.js';
import type {Projects} from '$routes/projects/projects.svelte.js';

export interface Repo_Viewmodel_Options {
	projects: Projects;
	project_id: Uuid;
	repo_id: Uuid | null;
}

/**
 * Controller for repo management functionality.
 */
export class Repo_Viewmodel {
	readonly projects: Projects;

	project_id: Uuid = $state()!;
	repo_id: Uuid | null = $state()!;

	git_url: string = $state()!;
	checkouts: Array<Repo_Checkout> = $state([]);

	/** Whether the form has unsaved changes. */
	readonly has_changes = $derived.by(
		() =>
			this.repo === null ||
			this.git_url !== this.repo.git_url ||
			// TODO this is bugged, doesn't show as having changes when only the checkouts have been edited
			JSON.stringify(this.checkouts) !== JSON.stringify(this.repo.checkouts),
	);

	/** The current project. */
	readonly project = $derived.by(() => this.projects.current_project);

	/** The repo being edited. */
	readonly repo = $derived.by(() => {
		const {repo_id} = this;
		if (!repo_id) return null;
		return this.project?.repos.find((r) => r.id === repo_id) || null;
	});

	/**
	 * Creates a new Repo_Viewmodel instance.
	 */
	constructor(options: Repo_Viewmodel_Options) {
		this.projects = options.projects;

		this.project_id = options.project_id;
		this.repo_id = options.repo_id;

		this.reset_form();
	}

	reset_form(): void {
		if (this.repo) {
			// Existing repo - use its values
			this.git_url = this.repo.git_url;
			this.checkouts = [...this.repo.checkouts];
		} else {
			// New repo - use default values
			this.git_url = '';
			this.checkouts = [];
		}
	}

	/**
	 * Add a new checkout directory
	 */
	add_checkout_dir(json?: Partial<Repo_Checkout>): void {
		this.checkouts.push({
			// TODO parse with schema
			id: create_uuid(),
			path: json?.path ?? '',
			label: json?.label ?? '',
			tags: json?.tags ?? [],
		});
	}

	/**
	 * Remove a checkout directory
	 */
	remove_checkout_dir(index: number): void {
		if (index >= 0 && index < this.checkouts.length) {
			this.checkouts.splice(index, 1);
		}
	}

	/**
	 * Save repo settings.
	 */
	save_repo_settings(): void {
		if (!this.project) return;

		const now = get_datetime_now();

		if (this.repo) {
			// Update existing repo
			this.repo.git_url = this.git_url;
			this.repo.checkouts = [...this.checkouts];
			this.repo.updated = now;
		} else {
			// Create new repo
			const repo = new Repo({
				app: this.projects.app,
				json: {
					git_url: this.git_url,
					checkouts: this.checkouts,
					created: now,
					updated: now,
				},
			});

			this.projects.add_repo(this.project_id, repo);
		}

		void goto(resolve(`/projects/${this.project_id}/repos`));
	}

	/**
	 * Remove a repo.
	 */
	remove_repo(): void {
		if (!this.project || !this.repo_id) return;

		// eslint-disable-next-line no-alert
		if (confirm('Are you sure you want to remove this repo? This action cannot be undone.')) {
			this.projects.delete_repo(this.project_id, this.repo_id);
			void goto(resolve(`/projects/${this.project_id}/repos`));
		}
	}
}

export const Repo_Viewmodel_Schema = z.instanceof(Repo_Viewmodel);
