import {goto} from '$app/navigation';

import {get_datetime_now} from '$lib/zod_helpers.js';
import {projects_context, type Domain, type Project, type Projects} from './projects.svelte.js';

/**
 * Controller for domain management functionality.
 */
export class Domains_Controller {
	/** The project ID. */
	readonly project_id: string;

	/** The domain ID being edited. */
	readonly domain_id: string;

	/** Projects service instance. */
	readonly projects: Projects;

	/** Domain name form field. */
	domain_name: string = $state('');

	/** Domain status form field. */
	domain_status: 'active' | 'pending' | 'inactive' = $state('pending');

	/** SSL enabled form field. */
	ssl_enabled: boolean = $state(false);

	/** Whether the form has been initialized. */
	#initialized: boolean = $state(false);

	/** Whether the form has unsaved changes. */
	has_changes = $derived(
		this.#initialized &&
			(!this.domain ||
				this.domain_name !== this.domain.name ||
				this.domain_status !== this.domain.status ||
				this.ssl_enabled !== this.domain.ssl),
	);

	/** The current project. */
	get project(): Project | null {
		return this.projects.current_project;
	}

	/** The domain being edited. */
	get domain(): Domain | null {
		return this.projects.current_domain;
	}

	/**
	 * Constructor for the domains controller.
	 * Does not initialize form values in the constructor to avoid reactivity issues.
	 */
	constructor(project_id: string, domain_id?: string | null, projects?: Projects) {
		this.project_id = project_id;
		this.domain_id = domain_id || '';
		this.projects = projects || projects_context.get();

		// TODO BLOCK remove/refactor
		// Init occurs after construction in the first derived computation
		$effect(() => {
			if (this.project && !this.#initialized) {
				this.init_form();
				this.#initialized = true;
			}
		});
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
	 * Saves domain settings.
	 */
	save_domain_settings(): void {
		if (!this.project || !this.domain) return;

		this.projects.update_domain(this.project_id, {
			...this.domain,
			name: this.domain_name,
			status: this.domain_status,
			ssl: this.ssl_enabled,
			updated: get_datetime_now(),
		});

		void goto(`/projects/${this.project_id}/domains`);
	}

	/**
	 * Removes a domain.
	 */
	remove_domain(): void {
		if (!this.project || !this.domain || !this.domain_id) return;

		// eslint-disable-next-line no-alert
		if (confirm('Are you sure you want to remove this domain? This action cannot be undone.')) {
			this.projects.delete_domain(this.project_id, this.domain_id);
			void goto(`/projects/${this.project_id}/domains`);
		}
	}

	/**
	 * Adds a new domain to the project.
	 */
	add_new_domain(): void {
		if (!this.project || !this.domain_name.trim()) return;

		const created = get_datetime_now();
		const new_domain: Domain = {
			id: 'dom_' + Date.now(),
			name: this.domain_name,
			status: this.domain_status,
			ssl: this.ssl_enabled,
			created,
			updated: created,
		};

		this.projects.add_domain(this.project_id, new_domain);
		void goto(`/projects/${this.project_id}/domains`);
	}
}
