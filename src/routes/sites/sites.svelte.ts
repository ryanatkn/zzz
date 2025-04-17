import {create_context} from '@ryanatkn/fuz/context_helpers.js';

export const projects_context = create_context<Projects>();

export interface Domain {
	id: string;
	name: string;
	status: 'active' | 'pending' | 'inactive';
	ssl: boolean;
	custom_domain: boolean;
}

export interface Page {
	id: string;
	path: string;
	title: string;
	content: string;
	created_at: string;
	updated_at: string;
}

export interface Project {
	id: string;
	name: string;
	description: string;
	created_at: string;
	updated_at: string;
	domains: Array<Domain>;
	pages: Array<Page>;
}

// Sample data
const sample_projects: Array<Project> = [
	{
		id: 'proj_1',
		name: 'My Blog',
		description: 'Personal blog about programming and tech',
		created_at: '2023-01-15T12:00:00Z',
		updated_at: '2023-04-20T15:30:00Z',
		domains: [
			{
				id: 'dom_1',
				name: 'myblog.zzz.software',
				status: 'active',
				ssl: true,
				custom_domain: false,
			},
			{
				id: 'dom_2',
				name: 'example.com',
				status: 'pending',
				ssl: false,
				custom_domain: true,
			},
		],
		pages: [
			{
				id: 'page_1',
				path: '/',
				title: 'Home',
				content: '# Welcome to my blog\n\nThis is the home page of my personal blog.',
				created_at: '2023-01-15T12:05:00Z',
				updated_at: '2023-01-16T09:30:00Z',
			},
			{
				id: 'page_2',
				path: '/about',
				title: 'About Me',
				content: '# About Me\n\nI am a developer who loves to write about technology.',
				created_at: '2023-01-15T14:20:00Z',
				updated_at: '2023-02-01T11:15:00Z',
			},
		],
	},
	{
		id: 'proj_2',
		name: 'Portfolio',
		description: 'My professional portfolio',
		created_at: '2023-02-10T09:15:00Z',
		updated_at: '2023-03-05T16:45:00Z',
		domains: [
			{
				id: 'dom_3',
				name: 'portfolio.zzz.software',
				status: 'active',
				ssl: true,
				custom_domain: false,
			},
		],
		pages: [
			{
				id: 'page_3',
				path: '/',
				title: 'Portfolio',
				content: '# My Portfolio\n\nCheck out my latest projects and skills.',
				created_at: '2023-02-10T10:00:00Z',
				updated_at: '2023-03-01T14:20:00Z',
			},
			{
				id: 'page_4',
				path: '/projects',
				title: 'Projects',
				content: '# Projects\n\nHere are some of the projects I have worked on.',
				created_at: '2023-02-11T11:30:00Z',
				updated_at: '2023-02-15T09:45:00Z',
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

	/**
	 * Adds a new project.
	 */
	add_project(project: Project): void {
		this.projects = [...this.projects, project];
	}

	/**
	 * Updates an existing project.
	 */
	update_project(project: Project): void {
		const index = this.projects.findIndex((p) => p.id === project.id);
		if (index !== -1) {
			this.projects = [
				...this.projects.slice(0, index),
				project,
				...this.projects.slice(index + 1),
			];
		}
	}

	/**
	 * Deletes a project by ID.
	 */
	delete_project(project_id: string): void {
		this.projects = this.projects.filter((p) => p.id !== project_id);
	}

	/**
	 * Adds a new page to a project.
	 */
	add_page(project_id: string, page: Page): void {
		const project_index = this.projects.findIndex((p) => p.id === project_id);
		if (project_index === -1) return;

		const project = this.projects[project_index];
		const updated_project = {
			...project,
			pages: [...project.pages, page],
			updated_at: new Date().toISOString(),
		};

		this.projects = [
			...this.projects.slice(0, project_index),
			updated_project,
			...this.projects.slice(project_index + 1),
		];
	}

	/**
	 * Updates an existing page.
	 */
	update_page(project_id: string, page: Page): void {
		const project_index = this.projects.findIndex((p) => p.id === project_id);
		if (project_index === -1) return;

		const project = this.projects[project_index];
		const page_index = project.pages.findIndex((p) => p.id === page.id);
		if (page_index === -1) return;

		const updated_pages = [
			...project.pages.slice(0, page_index),
			page,
			...project.pages.slice(page_index + 1),
		];

		const updated_project = {
			...project,
			pages: updated_pages,
			updated_at: new Date().toISOString(),
		};

		this.projects = [
			...this.projects.slice(0, project_index),
			updated_project,
			...this.projects.slice(project_index + 1),
		];
	}

	/**
	 * Deletes a page from a project.
	 */
	delete_page(project_id: string, page_id: string): void {
		const project_index = this.projects.findIndex((p) => p.id === project_id);
		if (project_index === -1) return;

		const project = this.projects[project_index];
		const updated_pages = project.pages.filter((p) => p.id !== page_id);

		const updated_project = {
			...project,
			pages: updated_pages,
			updated_at: new Date().toISOString(),
		};

		this.projects = [
			...this.projects.slice(0, project_index),
			updated_project,
			...this.projects.slice(project_index + 1),
		];
	}

	/**
	 * Adds a new domain to a project.
	 */
	add_domain(project_id: string, domain: Domain): void {
		const project_index = this.projects.findIndex((p) => p.id === project_id);
		if (project_index === -1) return;

		const project = this.projects[project_index];
		const updated_project = {
			...project,
			domains: [...project.domains, domain],
			updated_at: new Date().toISOString(),
		};

		this.projects = [
			...this.projects.slice(0, project_index),
			updated_project,
			...this.projects.slice(project_index + 1),
		];
	}

	/**
	 * Updates an existing domain.
	 */
	update_domain(project_id: string, domain: Domain): void {
		const project_index = this.projects.findIndex((p) => p.id === project_id);
		if (project_index === -1) return;

		const project = this.projects[project_index];
		const domain_index = project.domains.findIndex((d) => d.id === domain.id);
		if (domain_index === -1) return;

		const updated_domains = [
			...project.domains.slice(0, domain_index),
			domain,
			...project.domains.slice(domain_index + 1),
		];

		const updated_project = {
			...project,
			domains: updated_domains,
			updated_at: new Date().toISOString(),
		};

		this.projects = [
			...this.projects.slice(0, project_index),
			updated_project,
			...this.projects.slice(project_index + 1),
		];
	}

	/**
	 * Deletes a domain from a project.
	 */
	delete_domain(project_id: string, domain_id: string): void {
		const project_index = this.projects.findIndex((p) => p.id === project_id);
		if (project_index === -1) return;

		const project = this.projects[project_index];
		const updated_domains = project.domains.filter((d) => d.id !== domain_id);

		const updated_project = {
			...project,
			domains: updated_domains,
			updated_at: new Date().toISOString(),
		};

		this.projects = [
			...this.projects.slice(0, project_index),
			updated_project,
			...this.projects.slice(project_index + 1),
		];
	}
}

// Create singleton instance of the store
export const projects_store = new Projects();

// For backward compatibility, exposing the previous function interfaces
// that delegate to the class methods
export const add_project = (project: Project): void => {
	projects_store.add_project(project);
};

export const update_project = (project: Project): void => {
	projects_store.update_project(project);
};

export const delete_project = (project_id: string): void => {
	projects_store.delete_project(project_id);
};

export const add_page = (project_id: string, page: Page): void => {
	projects_store.add_page(project_id, page);
};

export const update_page = (project_id: string, page: Page): void => {
	projects_store.update_page(project_id, page);
};

export const delete_page = (project_id: string, page_id: string): void => {
	projects_store.delete_page(project_id, page_id);
};

export const add_domain = (project_id: string, domain: Domain): void => {
	projects_store.add_domain(project_id, domain);
};

export const update_domain = (project_id: string, domain: Domain): void => {
	projects_store.update_domain(project_id, domain);
};

export const delete_domain = (project_id: string, domain_id: string): void => {
	projects_store.delete_domain(project_id, domain_id);
};
