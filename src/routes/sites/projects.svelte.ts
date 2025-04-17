import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import {goto} from '$app/navigation';
import {SvelteMap} from 'svelte/reactivity';

import {Project_Controller} from './project_controller.svelte.js';
import {Page_Editor} from './page_editor.svelte.js';
import {Domains_Controller} from './domains.svelte.js';

export const projects_context = create_context<Projects>();

export interface Domain {
	id: string;
	name: string;
	status: 'active' | 'pending' | 'inactive';
	ssl: boolean;
}

export interface Page {
	id: string;
	path: string;
	title: string;
	content: string;
	created: string;
	updated: string;
}

export interface Project {
	id: string;
	name: string;
	description: string;
	created: string;
	updated: string;
	domains: Array<Domain>;
	pages: Array<Page>;
}

// Sample data
const sample_projects: Array<Project> = [
	{
		id: 'proj_1',
		name: 'Zzz',
		description: 'The Zzz project website',
		created: '2023-01-15T12:00:00Z',
		updated: '2023-04-20T15:30:00Z',
		domains: [
			{
				id: 'dom_1',
				name: 'zzz.software',
				status: 'active',
				ssl: true,
			},
			{
				id: 'dom_2',
				name: 'www.zzz.software',
				status: 'active',
				ssl: true,
			},
		],
		pages: [
			{
				id: 'page_1',
				path: '/',
				title: 'Home',
				content: '# Welcome to Zzz\n\nZzz is both a browser and editor for the read-write web.',
				created: '2023-01-15T12:05:00Z',
				updated: '2023-01-16T09:30:00Z',
			},
			{
				id: 'page_2',
				path: '/about',
				title: 'About',
				content:
					'# About Zzz\n\nZzz is a project that aims to make managing websites routine and easy.',
				created: '2023-01-15T14:20:00Z',
				updated: '2023-02-01T11:15:00Z',
			},
		],
	},
	{
		id: 'proj_2',
		name: 'Dealt',
		description: 'Tarot card reading and interpretation',
		created: '2023-02-10T09:15:00Z',
		updated: '2023-03-05T16:45:00Z',
		domains: [
			{
				id: 'dom_3',
				name: 'dealt.dev',
				status: 'active',
				ssl: true,
			},
			{
				id: 'dom_4',
				name: 'tarot.dealt.dev',
				status: 'active',
				ssl: true,
			},
		],
		pages: [
			{
				id: 'page_3',
				path: '/',
				title: 'Dealt',
				content: '# Dealt\n\nA modern approach to tarot card reading.',
				created: '2023-02-10T10:00:00Z',
				updated: '2023-03-01T14:20:00Z',
			},
			{
				id: 'page_4',
				path: '/readings',
				title: 'Readings',
				content: '# Tarot Readings\n\nExplore different card spreads and their meanings.',
				created: '2023-02-11T11:30:00Z',
				updated: '2023-02-15T09:45:00Z',
			},
		],
	},
];

/**
 * Manages projects, pages, and domains using Svelte 5 runes.
 */
export class Projects {
	/** Collection of all projects. */
	projects: Array<Project> = $state(sample_projects);

	/** UI state for preview mode in the sites view. */
	previewing: boolean = $state(false);

	/** UI state for tracking expanded projects in the sidebar. */
	expanded_projects: Record<string, boolean> = $state({});

	/** Current project ID from URL params. */
	current_project_id: string = $state('');

	/** Current page ID from URL params. */
	current_page_id: string = $state('');

	/** Current domain ID from URL params. */
	current_domain_id: string = $state('');

	/** Current project derived from current_project_id. */
	current_project = $derived(this.projects.find((p) => p.id === this.current_project_id) || null);

	/** Current page derived from current_project and current_page_id. */
	current_page = $derived(
		this.current_project?.pages.find((p) => p.id === this.current_page_id) || null,
	);

	/** Current domain derived from current_project and current_domain_id. */
	current_domain = $derived(
		this.current_project?.domains.find((d) => d.id === this.current_domain_id) || null,
	);

	/** Cache of controller instances. */
	#controllers: Map<string, Project_Controller> = new SvelteMap();

	/** Cache of page editor instances. */
	#page_editors: Map<string, Page_Editor> = new SvelteMap();

	/** Cache of domains controller instances. */
	#domains_controllers: Map<string, Domains_Controller> = new SvelteMap();

	/**
	 * Sets the current project ID.
	 */
	set_current_project(project_id: string): void {
		this.current_project_id = project_id;
	}

	/**
	 * Sets the current page ID.
	 */
	set_current_page(page_id: string): void {
		this.current_page_id = page_id;
	}

	/**
	 * Sets the current domain ID.
	 */
	set_current_domain(domain_id: string): void {
		this.current_domain_id = domain_id;
	}

	/**
	 * Creates a new project with default values and navigates to it.
	 */
	create_new_project(): void {
		const id = 'proj_' + Date.now();
		const timestamp = new Date().toISOString();

		const new_project: Project = {
			id,
			name: 'New Project',
			description: '',
			created: timestamp,
			updated: timestamp,
			domains: [],
			pages: [
				{
					id: 'page_' + Date.now(),
					path: '/',
					title: 'Home',
					content: '# Welcome\n\nThis is the home page of your new project.',
					created: timestamp,
					updated: timestamp,
				},
			],
		};

		this.add_project(new_project);
		void goto(`/sites/${id}`);
	}

	/**
	 * Gets or creates a project controller for the given project ID.
	 */
	get_project_controller(project_id = this.current_project_id): Project_Controller {
		let controller = this.#controllers.get(project_id);
		if (!controller) {
			this.#controllers.set(project_id, (controller = new Project_Controller(project_id, this)));
		}
		return controller;
	}

	/**
	 * Gets or creates a page editor for the given project ID and page ID.
	 */
	get_page_editor(
		project_id = this.current_project_id,
		page_id = this.current_page_id,
	): Page_Editor {
		const key = `${project_id}_${page_id}`;
		let editor = this.#page_editors.get(key);
		if (!editor) {
			this.#page_editors.set(key, (editor = new Page_Editor(project_id, page_id, this)));
		}
		return editor;
	}

	/**
	 * Gets or creates a domains controller for the given project ID and domain ID.
	 */
	get_domains_controller(
		project_id = this.current_project_id,
		domain_id = this.current_domain_id,
	): Domains_Controller {
		const key = `${project_id}_${domain_id || 'new'}`;
		let controller = this.#domains_controllers.get(key);
		if (!controller) {
			this.#domains_controllers.set(
				key,
				(controller = new Domains_Controller(project_id, domain_id, this)),
			);
		}
		return controller;
	}

	/**
	 * Toggles project expansion in the sidebar.
	 */
	toggle_project_expanded(project_id: string): void {
		this.expanded_projects[project_id] = !this.expanded_projects[project_id];
	}

	/**
	 * Adds a new project.
	 */
	add_project(project: Project): void {
		this.projects.push(project);
	}

	/**
	 * Updates an existing project.
	 */
	update_project(project: Project): void {
		const index = this.projects.findIndex((p) => p.id === project.id);
		if (index !== -1) {
			this.projects[index] = project;
		}
	}

	/**
	 * Deletes a project by ID.
	 */
	delete_project(project_id: string): void {
		const index = this.projects.findIndex((p) => p.id === project_id);
		if (index !== -1) {
			this.projects.splice(index, 1);
		}
	}

	/**
	 * Adds a new page to a project.
	 */
	add_page(project_id: string, page: Page): void {
		const project = this.projects.find((p) => p.id === project_id);
		if (!project) return;

		project.pages.push(page);
		project.updated = new Date().toISOString();
	}

	/**
	 * Updates an existing page.
	 */
	update_page(project_id: string, page: Page): void {
		const project = this.projects.find((p) => p.id === project_id);
		if (!project) return;

		const page_index = project.pages.findIndex((p) => p.id === page.id);
		if (page_index === -1) return;

		project.pages[page_index] = page;
		project.updated = new Date().toISOString();
	}

	/**
	 * Deletes a page from a project.
	 */
	delete_page(project_id: string, page_id: string): void {
		const project = this.projects.find((p) => p.id === project_id);
		if (!project) return;

		const page_index = project.pages.findIndex((p) => p.id === page_id);
		if (page_index === -1) return;

		project.pages.splice(page_index, 1);
		project.updated = new Date().toISOString();
	}

	/**
	 * Adds a new domain to a project.
	 */
	add_domain(project_id: string, domain: Domain): void {
		const project = this.projects.find((p) => p.id === project_id);
		if (!project) return;

		project.domains.push(domain);
		project.updated = new Date().toISOString();
	}

	/**
	 * Updates an existing domain.
	 */
	update_domain(project_id: string, domain: Domain): void {
		const project = this.projects.find((p) => p.id === project_id);
		if (!project) return;

		const domain_index = project.domains.findIndex((d) => d.id === domain.id);
		if (domain_index === -1) return;

		project.domains[domain_index] = domain;
		project.updated = new Date().toISOString();
	}

	/**
	 * Deletes a domain from a project.
	 */
	delete_domain(project_id: string, domain_id: string): void {
		const project = this.projects.find((p) => p.id === project_id);
		if (!project) return;

		const domain_index = project.domains.findIndex((d) => d.id === domain_id);
		if (domain_index === -1) return;

		project.domains.splice(domain_index, 1);
		project.updated = new Date().toISOString();
	}
}
