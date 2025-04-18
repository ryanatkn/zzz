import {z} from 'zod';
import {Cell_Json} from '$lib/cell_types.js';
import {Uuid} from '$lib/zod_helpers.js';
import {cell_array} from '$lib/cell_helpers.js';

// Domain schema
export const Domain_Json = Cell_Json.extend({
	name: z.string().default(''),
	status: z.enum(['active', 'pending', 'inactive']).default('pending'),
	ssl: z.boolean().default(false),
});
export type Domain_Json = z.infer<typeof Domain_Json>;
export type Domain_Json_Input = z.input<typeof Domain_Json>;

// Page schema
export const Page_Json = Cell_Json.extend({
	path: z.string().default('/'),
	title: z.string().default('New Page'),
	content: z.string().default('# New Page\n\nAdd your content here.'),
});
export type Page_Json = z.infer<typeof Page_Json>;
export type Page_Json_Input = z.input<typeof Page_Json>;

// Project schema
export const Project_Json = Cell_Json.extend({
	name: z.string().default('new project'),
	description: z.string().default(''),
	pages: cell_array(
		z.array(Page_Json).default(() => []),
		'Page',
	),
	domains: cell_array(
		z.array(Domain_Json).default(() => []),
		'Domain',
	),
});
export type Project_Json = z.infer<typeof Project_Json>;
export type Project_Json_Input = z.input<typeof Project_Json>;

// Projects collection schema
export const Projects_Json = Cell_Json.extend({
	projects: cell_array(
		z.array(Project_Json).default(() => []),
		'Project',
	),
	current_project_id: Uuid.nullable().default(null),
	current_page_id: Uuid.nullable().default(null),
	current_domain_id: Uuid.nullable().default(null),
	expanded_projects: z.record(z.string(), z.boolean()).default({}),
	previewing: z.boolean().default(false),
});
export type Projects_Json = z.infer<typeof Projects_Json>;
export type Projects_Json_Input = z.input<typeof Projects_Json>;
