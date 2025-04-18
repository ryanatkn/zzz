import {z} from 'zod';
import {goto} from '$app/navigation';
import {base} from '$app/paths';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Domain_Controller_Json} from './projects_schema.js';
import {get_datetime_now, type Uuid} from '$lib/zod_helpers.js';
import {Domain} from './domain.svelte.js';
import type {Projects} from './projects.svelte.js';

export interface Domain_Controller_Options extends Cell_Options<typeof Domain_Controller_Json> {
	projects: Projects;
}

/**
 * Controller for domain management functionality.
 */
export class Domain_Controller extends Cell<typeof Domain_Controller_Json> {
	project_id: Uuid = $state()!;
	domain_id?: Uuid = $state();
	domain_name: string = $state()!;
	domain_status: 'active' | 'pending' | 'inactive' = $state()!;
	ssl_enabled: boolean = $state()!;
	is_initialized: boolean = $state()!;

	/** Projects service instance. */
	readonly projects: Projects;

	/** Whether the form has unsaved changes. */
	has_changes = $derived.by(
		() =>
			this.is_initialized &&
			(this.domain === null ||
				this.domain_name !== this.domain.name ||
				this.domain_status !== this.domain.status ||
				this.ssl_enabled !== this.domain.ssl),
	);

	/** The current project. */
	readonly project = $derived.by(() => this.projects.current_project);

	/** The domain being edited. */
	readonly domain = $derived.by(() => {
		if (!this.domain_id) return null;
		return this.project?.domains.find((d) => d.id === this.domain_id) || null;
	});

	/**
	 * Creates a new Domain_Controller instance.
	 */
	constructor(options: Domain_Controller_Options) {
		super(Domain_Controller_Json, options);

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
	 * Initialize form values from current domain or with defaults.
	 */
	init_form(): void {
		if (this.domain) {
			// Existing domain - use its values
			this.domain_name = this.domain.name;
			this.domain_status = this.domain.status;
			this.ssl_enabled = this.domain.ssl;
		} else {
			// New domain - use default values
			this.domain_name = '';
			this.domain_status = 'pending';
			this.ssl_enabled = false;
		}
	}

	/**
	 * Save domain settings.
	 */
	save_domain_settings(): void {
		if (!this.project) return;

		const now = get_datetime_now();

		if (this.domain) {
			// Update existing domain
			this.domain.name = this.domain_name;
			this.domain.status = this.domain_status;
			this.domain.ssl = this.ssl_enabled;
			this.domain.updated = now;
		} else {
			// Create new domain
			const domain = new Domain({
				zzz: this.zzz,
				json: {
					name: this.domain_name,
					status: this.domain_status,
					ssl: this.ssl_enabled,
					created: now,
					updated: now,
				},
			});

			this.projects.add_domain(this.project_id, domain);
		}

		void goto(`${base}/projects/${this.project_id}/domains`);
	}

	/**
	 * Remove a domain.
	 */
	remove_domain(): void {
		if (!this.project || !this.domain_id) return;

		// eslint-disable-next-line no-alert
		if (confirm('Are you sure you want to remove this domain? This action cannot be undone.')) {
			this.projects.delete_domain(this.project_id, this.domain_id);
			void goto(`${base}/projects/${this.project_id}/domains`);
		}
	}
}

export const Domain_Controller_Schema = z.instanceof(Domain_Controller);
