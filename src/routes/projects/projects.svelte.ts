import {z} from 'zod';
import {create_context} from '@ryanatkn/fuz/context_helpers.js';

import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Projects_Json} from './projects_schema.js';
import {Project} from './project.svelte.js';
import {Page} from './page.svelte.js';
import {Domain} from './domain.svelte.js';
import {Project_Controller} from './project_controller.svelte.js';
import {Page_Editor} from './page_editor.svelte.js';
import {Domain_Controller} from './domains.svelte.js';
import {get_datetime_now, create_uuid, Uuid} from '$lib/zod_helpers.js';
import {HANDLED} from '$lib/cell_helpers.js';
import {get_unique_name} from '$lib/helpers.js';
import type {Zzz} from '$lib/zzz.svelte.js';

export const projects_context = create_context<Projects>();

export type Projects_Options = Cell_Options<typeof Projects_Json>;

// Sample data for initial projects
const create_sample_projects = (zzz: Zzz): Array<Project> => {
	return [
		new Project({
			zzz,
			json: {
				id: 'proj_1',
				name: 'Zzz',
				description: 'webtool 💤 nice web things for the tired',
				created: '2023-01-15T12:00:00Z',
				updated: '2023-04-20T15:30:00Z',
				domains: [
					{
						id: 'dom_1',
						name: 'zzz.software',
						status: 'active',
						ssl: true,
						created: '2023-01-15T12:00:00Z',
						updated: '2023-04-20T15:30:00Z',
					},
					{
						id: 'dom_2',
						name: 'zzz.zzz.software',
						status: 'active',
						ssl: true,
						created: '2023-01-15T12:00:00Z',
						updated: '2023-04-20T15:30:00Z',
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
		}),
		new Project({
			zzz,
			json: {
				id: 'proj_2',
				name: 'Dealt',
				description: 'toy 2D web game engine with a focus on topdown action RPGs 🔮',
				created: '2023-02-10T09:15:00Z',
				updated: '2023-03-05T16:45:00Z',
				domains: [
					{
						id: 'dom_3',
						name: 'dealt.dev',
						status: 'active',
						ssl: true,
						created: '2023-02-10T09:15:00Z',
						updated: '2023-03-05T16:45:00Z',
					},
					{
						id: 'dom_4',
						name: 'tarot.dealt.dev',
						status: 'active',
						ssl: true,
						created: '2023-02-10T09:15:00Z',
						updated: '2023-03-05T16:45:00Z',
					},
				],
				pages: [
					{
						id: 'page_3',
						path: '/',
						title: 'Dealt',
						content:
							'# Dealt\n\ntoy 2D web game engine with a focus on topdown action RPGs 🔮 <a href="https://www.dealt.dev/">dealt.dev</a>',
						created: '2023-02-10T10:00:00Z',
						updated: '2023-03-01T14:20:00Z',
					},
					{
						id: 'page_4',
						path: '/tarot',
						title: 'Dealt: tarot',
						content:
							'# Tarot\n\ngiving meaning a chance 🔮 <a href="https://tarot.dealt.dev/">tarot.dealt.dev</a>',
						created: '2023-02-11T11:30:00Z',
						updated: '2023-02-15T09:45:00Z',
					},
				],
			},
		}),
		new Project({
			zzz,
			json: {
				id: 'proj_3',
				name: 'cosmicplayground',
				description: 'tools and toys for expanding minds 🌌',
				created: '2023-05-15T08:00:00Z',
				updated: '2023-06-20T14:15:00Z',
				domains: [
					{
						id: 'dom_5',
						name: 'cosmicplayground.org',
						status: 'active',
						ssl: true,
						created: '2023-05-15T08:00:00Z',
						updated: '2023-06-20T14:15:00Z',
					},
				],
				pages: [],
			},
		}),
	];
};

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

	/** Cache of project controllers. */
	#controllers: Map<string, Project_Controller> = new Map();

	/** Cache of page editors. */
	#page_editors: Map<string, Page_Editor> = new Map();

	/** Cache of domain controllers. */
	#domains_controllers: Map<string, Domain_Controller> = new Map();

	/** Current project controller derived from current_project_id. */
	readonly current_project_controller = $derived.by(() => {
		if (!this.current_project_id) return null;

		let controller = this.#controllers.get(this.current_project_id);
		if (!controller) {
			controller = new Project_Controller({
				projects: this,
				zzz: this.zzz,
				json: {
					project_id: this.current_project_id,
				},
			});
			this.#controllers.set(this.current_project_id, controller);
		}
		return controller;
	});

	/** Current page editor derived from current project and page IDs. */
	readonly current_page_editor = $derived.by(() => {
		if (!this.current_project_id || !this.current_page_id) return null;

		const key = `${this.current_project_id}_${this.current_page_id}`;
		let editor = this.#page_editors.get(key);
		if (!editor) {
			editor = new Page_Editor({
				projects: this,
				zzz: this.zzz,
				json: {
					project_id: this.current_project_id,
					page_id: this.current_page_id,
				},
			});
			this.#page_editors.set(key, editor);
		}
		return editor;
	});

	/** Current domains controller derived from current project and domain IDs. */
	readonly current_domains_controller = $derived.by(() => {
		if (!this.current_project_id) return null;

		const key = `${this.current_project_id}_${this.current_domain_id || 'new'}`;
		let controller = this.#domains_controllers.get(key);
		if (!controller) {
			controller = new Domain_Controller({
				projects: this,
				zzz: this.zzz,
				json: {
					project_id: this.current_project_id,
					domain_id: this.current_domain_id,
				},
			});
			this.#domains_controllers.set(key, controller);
		}
		return controller;
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
					this.projects = create_sample_projects(this.zzz);
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
