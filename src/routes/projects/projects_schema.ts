import {z} from 'zod';
import {Cell_Json} from '$lib/cell_types.js';
import {Uuid} from '$lib/zod_helpers.js';

export const Domain_Json = Cell_Json.extend({
	name: z.string().default(''),
	status: z.enum(['active', 'pending', 'inactive']).default('pending'),
	ssl: z.boolean().default(false),
}).meta({cell_class_name: 'Domain'});
export type Domain_Json = z.infer<typeof Domain_Json>;
export type Domain_Json_Input = z.input<typeof Domain_Json>;

export const Page_Json = Cell_Json.extend({
	path: z.string().default('/'),
	title: z.string().default('New page'),
	content: z.string().default('# New page\n\nAdd your content here.'),
}).meta({cell_class_name: 'Page'});
export type Page_Json = z.infer<typeof Page_Json>;
export type Page_Json_Input = z.input<typeof Page_Json>;

export const Repo_Checkout = z.strictObject({
	id: Uuid,
	path: z.string(),
	label: z.string(),
	tags: z.array(z.string()),
});
export type Repo_Checkout = z.infer<typeof Repo_Checkout>;

export const Repo_Json = Cell_Json.extend({
	git_url: z.string(),
	checkouts: z.array(Repo_Checkout).default([]),
}).meta({cell_class_name: 'Repo'});
export type Repo_Json = z.infer<typeof Repo_Json>;
export type Repo_Json_Input = z.input<typeof Repo_Json>;

export const Project_Json = Cell_Json.extend({
	name: z.string().default('new project'),
	description: z.string().default(''),
	pages: z.array(Page_Json).default(() => []),
	domains: z.array(Domain_Json).default(() => []),
	repos: z.array(Repo_Json).default([]),
}).meta({cell_class_name: 'Project'});
export type Project_Json = z.infer<typeof Project_Json>;
export type Project_Json_Input = z.input<typeof Project_Json>;

export const Projects_Json = Cell_Json.extend({
	projects: z.array(Project_Json).default(() => []),
	current_project_id: Uuid.nullable().default(null),
	current_page_id: Uuid.nullable().default(null),
	current_domain_id: Uuid.nullable().default(null),
	expanded_projects: z.record(z.string(), z.boolean()).default({}),
	previewing: z.boolean().default(false),
}).meta({cell_class_name: 'Projects'});
export type Projects_Json = z.infer<typeof Projects_Json>;
export type Projects_Json_Input = z.input<typeof Projects_Json>;
