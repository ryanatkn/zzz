import {z} from 'zod';
import {create_context} from '@ryanatkn/fuz/context_helpers.js';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Projects_Json} from './projects_schema.js';
import {Project} from './project.svelte.js';
import {Page} from './page.svelte.js';
import {Domain} from './domain.svelte.js';
import {Project_Viewmodel} from './project_viewmodel.svelte.js';
import {Page_Viewmodel} from './page_viewmodel.svelte.js';
import {Domain_Viewmodel} from './domain_viewmodel.svelte.js';
import {get_datetime_now, create_uuid, Uuid} from '$lib/zod_helpers.js';
import {HANDLED} from '$lib/cell_helpers.js';
import {get_unique_name} from '$lib/helpers.js';
import {create_sample_projects as create_example_projects} from './example_projects.js';

export const projects_context = create_context<Projects>();

export type Projects_Options = Cell_Options<typeof Projects_Json>;

/**
 * Manages projects, pages, and domains using Svelte 5 runes and Cell patterns.
 */
export class Projects extends Cell<typeof Projects_Json> {
	projects: Array<Project> = $state([]);
	current_project_id: Uuid | null = $state(null);
	current_page_id: Uuid | null = $state(null);
	current_domain_id: Uuid | null = $state(null);
	expanded_projects: Record<string, boolean> = $state({});
	previewing: boolean = $state(false);

	/** Map of project name to project for checking uniqueness */
	readonly items_by_name = $derived.by(() => {
		const result: Map<string, Project> = new Map();
		for (const project of this.projects) {
			result.set(project.name, project);
		}
		return result;
	});

	/** Current project derived from current_project_id. */
	readonly current_project = $derived(
		this.projects.find((p) => p.id === this.current_project_id) || null,
	);

	/** Current page derived from current_project and current_page_id. */
	readonly current_page = $derived(
		this.current_project?.pages.find((p) => p.id === this.current_page_id) || null,
	);

	/** Current domain derived from current_project and current_domain_id. */
	readonly current_domain = $derived(
		this.current_project?.domains.find((d) => d.id === this.current_domain_id) || null,
	);

	/** Cache of project viewmodels. */
	#project_viewmodels: Map<string, Project_Viewmodel> = new Map();

	/** Cache of page editors. */
	#page_viewmodels: Map<string, Page_Viewmodel> = new Map();

	/** Cache of domain viewmodels. */
	#domain_viewmodels: Map<string, Domain_Viewmodel> = new Map();

	/** Current project viewmodel derived from current_project_id. */
	readonly current_project_viewmodel = $derived.by(() => {
		if (!this.current_project_id) return null;

		let viewmodel = this.#project_viewmodels.get(this.current_project_id);
		if (!viewmodel) {
			viewmodel = new Project_Viewmodel({
				projects: this,
				project_id: this.current_project_id,
			});
			this.#project_viewmodels.set(this.current_project_id, viewmodel);
		}
		return viewmodel;
	});

	/** Current page editor derived from current project and page IDs. */
	readonly current_page_editor = $derived.by(() => {
		if (!this.current_project_id || !this.current_page_id) return null;

		const key = `${this.current_project_id}_${this.current_page_id}`;
		let editor = this.#page_viewmodels.get(key);
		if (!editor) {
			editor = new Page_Viewmodel({
				projects: this,
				project_id: this.current_project_id,
				page_id: this.current_page_id,
			});
			this.#page_viewmodels.set(key, editor);
		}
		return editor;
	});

	/** Current domains viewmodel derived from current project and domain IDs. */
	readonly current_domains_viewmodel = $derived.by(() => {
		if (!this.current_project_id) return null;

		if (!this.current_domain_id) {
			console.error('TODO ? current_domain_id is null'); // TODO looks weird
		}
		const key = `${this.current_project_id}_${this.current_domain_id || 'new'}`;
		let viewmodel = this.#domain_viewmodels.get(key);
		if (!viewmodel) {
			viewmodel = new Domain_Viewmodel({
				projects: this,
				project_id: this.current_project_id,
				domain_id: this.current_domain_id,
			});
			this.#domain_viewmodels.set(key, viewmodel);
		}
		return viewmodel;
	});

	constructor(options: Projects_Options) {
		super(Projects_Json, options);

		this.decoders = {
			// TODO hacky
			projects: (projects_data) => {
				if (Array.isArray(projects_data)) {
					this.projects = projects_data.map(
						(project_data) => new Project({zzz: this.zzz, json: project_data}),
					);
					return HANDLED;
				}

				// If no projects provided, initialize with sample data
				if (!projects_data || !Array.isArray(projects_data) || projects_data.length === 0) {
					this.projects = create_example_projects(this.zzz);
					return HANDLED;
				}

				return undefined;
			},
		};

		this.init();
	}

	/**
	 * Sets the current project ID.
	 */
	set_current_project(project_id: Uuid | null): void {
		console.log(`set_current_project`, project_id);
		this.current_project_id = project_id;
	}

	/**
	 * Sets the current page ID.
	 */
	set_current_page(page_id: Uuid | null): void {
		console.log(`set_current_page`, page_id);
		this.current_page_id = page_id;
	}

	/**
	 * Sets the current domain ID.
	 */
	set_current_domain(domain_id: Uuid | null): void {
		console.log(`set_current_domain`, domain_id);
		this.current_domain_id = domain_id;
	}

	/**
	 * Creates a new project with default values and navigates to it.
	 */
	create_new_project(): Project {
		const base_name = 'new project';
		const name = get_unique_name(base_name, this.items_by_name);

		const id = create_uuid();
		const created = get_datetime_now();

		const new_project = new Project({
			zzz: this.zzz,
			json: {
				id,
				name,
				created,
				updated: created,
				pages: [
					{
						id: create_uuid(),
						path: '/',
						title: 'Home',
						content: '# Welcome\n\nThis is the home page of your new project.',
						created,
						updated: created,
					},
				],
			},
		});

		this.add_project(new_project);

		return new_project;
	}

	/**
	 * Toggles project expansion in the sidebar.
	 */
	toggle_project_expanded(project_id: Uuid): void {
		this.expanded_projects[project_id] = !this.expanded_projects[project_id];
	}

	/**
	 * Adds a new project.
	 */
	add_project(project: Project): void {
		this.projects.push(project);
	}

	/**
	 * Deletes a project by ID.
	 */
	delete_project(project_id: Uuid): void {
		const index = this.projects.findIndex((p) => p.id === project_id);
		if (index !== -1) {
			this.projects.splice(index, 1);
		}
	}

	/**
	 * Adds a new page to a project.
	 */
	add_page(project_id: Uuid, page: Page): void {
		const project = this.projects.find((p) => p.id === project_id);
		if (!project) return;

		project.add_page(page);
	}

	/**
	 * Deletes a page from a project.
	 */
	delete_page(project_id: Uuid, page_id: Uuid): void {
		const project = this.projects.find((p) => p.id === project_id);
		if (!project) return;

		project.delete_page(page_id);
	}

	/**
	 * Adds a new domain to a project.
	 */
	add_domain(project_id: Uuid, domain: Domain): void {
		const project = this.projects.find((p) => p.id === project_id);
		if (!project) return;

		project.add_domain(domain);
	}

	/**
	 * Updates an existing domain.
	 */
	update_domain(project_id: Uuid, domain: Domain): void {
		const project = this.projects.find((p) => p.id === project_id);
		if (!project) return;

		project.update_domain(domain);
	}

	/**
	 * Deletes a domain from a project.
	 */
	delete_domain(project_id: Uuid, domain_id: Uuid): void {
		const project = this.projects.find((p) => p.id === project_id);
		if (!project) return;

		project.delete_domain(domain_id);
	}
}

export const Projects_Schema = z.instanceof(Projects);
