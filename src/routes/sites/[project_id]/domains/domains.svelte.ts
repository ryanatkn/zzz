import {goto} from '$app/navigation';
import {
	projects_store,
	update_domain,
	delete_domain,
	type Domain,
	type Project,
} from '../../sites.svelte.js';

/**
 * Controller for domain management functionality.
 */
export class Domains_Controller {
	/** The project ID. */
	readonly project_id: string;

	/** The current project. */
	readonly project: Project | null = $derived(
		projects_store.projects.find((p) => p.id === this.project_id) || null,
	);

	/** The domain being edited. */
	readonly domain: Domain | null = $derived.by(() =>
		this.domain_id ? this.project?.domains.find((d) => d.id === this.domain_id) || null : null,
	);

	/** Domain name form field. */
	domain_name: string = $state('');

	/** Domain status form field. */
	domain_status: 'active' | 'pending' | 'inactive' = $state('pending');

	/** SSL enabled form field. */
	ssl_enabled: boolean = $state(false);

	/** Custom domain flag form field. */
	custom_domain: boolean = $state(false);

	/** Constructor for the domains controller. */
	constructor(project_id: string, domain_id?: string) {
		this.project_id = project_id;
		this.domain_id = domain_id || null;

		// Initialize form values when domain is available
		$effect(() => {
			if (this.domain) {
				this.domain_name = this.domain.name;
				this.domain_status = this.domain.status;
				this.ssl_enabled = this.domain.ssl;
				this.custom_domain = this.domain.custom_domain;
			}
		});
	}

	/** The domain ID being edited. */
	domain_id: string | null = $state(null);

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

		update_domain(this.project_id, {
			...this.domain,
			name: this.domain_name,
			status: this.domain_status,
			ssl: this.ssl_enabled,
			custom_domain: this.custom_domain,
		});

		void goto(`/sites/${this.project_id}`);
	}

	/**
	 * Removes a domain.
	 */
	remove_domain(): void {
		if (!this.project || !this.domain || !this.domain_id) return;

		// eslint-disable-next-line no-alert
		if (confirm('Are you sure you want to remove this domain? This action cannot be undone.')) {
			delete_domain(this.project_id, this.domain_id);
			void goto(`/sites/${this.project_id}`);
		}
	}
}
