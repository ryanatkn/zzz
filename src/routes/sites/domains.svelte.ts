import {goto} from '$app/navigation';
import {projects_context, type Domain, type Project, type Projects} from './projects.svelte.js';

/**
 * Controller for domain management functionality.
 */
export class Domains_Controller {
	/** The project ID. */
	readonly project_id: string;

	/** Projects service instance. */
	readonly projects: Projects;

	/** Domain name form field. */
	domain_name: string = $state('');

	/** Domain status form field. */
	domain_status: 'active' | 'pending' | 'inactive' = $state('pending');

	/** SSL enabled form field. */
	ssl_enabled: boolean = $state(false);

	/** Whether the form has unsaved changes. */
	has_changes = $derived(
		!this.domain ||
			this.domain_name !== this.domain.name ||
			this.domain_status !== this.domain.status ||
			this.ssl_enabled !== this.domain.ssl,
	);

	/** The current project. */
	get project(): Project | null {
		return this.projects.current_project;
	}

	/** The domain being edited. */
	get domain(): Domain | null {
		return this.projects.current_domain;
	}

	/** The domain ID being edited. */
	get domain_id(): string {
		return this.projects.current_domain_id;
	}

	/**
	 * Constructor for the domains controller.
	 */
	constructor(project_id: string, domain_id?: string, projects?: Projects) {
		this.project_id = project_id;
		this.projects = projects || projects_context.get();

		// Initialize form values based on domain ID
		if (domain_id && domain_id !== 'new') {
			this.projects.set_current_domain(domain_id);
			this.init_form();
		} else {
			// Default values for new domains
			this.domain_name = '';
			this.domain_status = 'pending';
			this.ssl_enabled = false;
		}
	}

	/**
	 * Initialize form values from current domain.
	 */
	init_form(): void {
		if (this.domain) {
			this.domain_name = this.domain.name;
			this.domain_status = this.domain.status;
			this.ssl_enabled = this.domain.ssl;
		}
	}

	/**
	 * Saves domain settings.
	 */
	save_domain_settings(): void {
		if (!this.project || !this.domain) return;

		// Basic validation
		if (!this.domain_name.trim() || !this.domain_name.includes('.')) {
			// eslint-disable-next-line no-alert
			alert('Please enter a valid domain name.');
			return;
		}

		this.projects.update_domain(this.project_id, {
			...this.domain,
			name: this.domain_name,
			status: this.domain_status,
			ssl: this.ssl_enabled,
		});

		void goto(`/sites/${this.project_id}/domains`);
	}

	/**
	 * Removes a domain.
	 */
	remove_domain(): void {
		if (!this.project || !this.domain || !this.domain_id) return;

		// eslint-disable-next-line no-alert
		if (confirm('Are you sure you want to remove this domain? This action cannot be undone.')) {
			this.projects.delete_domain(this.project_id, this.domain_id);
			void goto(`/sites/${this.project_id}/domains`);
		}
	}

	/**
	 * Adds a new domain to the project.
	 */
	add_new_domain(): void {
		if (!this.project || !this.domain_name.trim()) return;

		// Basic validation
		if (!this.domain_name.includes('.')) {
			// eslint-disable-next-line no-alert
			alert('Please enter a valid domain name.');
			return;
		}

		const new_domain: Domain = {
			id: 'dom_' + Date.now(),
			name: this.domain_name,
			status: this.domain_status,
			ssl: this.ssl_enabled,
		};

		this.projects.add_domain(this.project_id, new_domain);
		void goto(`/sites/${this.project_id}/domains`);
	}
}
