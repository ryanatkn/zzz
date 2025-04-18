<script module lang="ts">
	let projects: Projects;
</script>

<script lang="ts">
	import {type Snippet} from 'svelte';

	import {projects_context, Projects} from './projects.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	const zzz = zzz_context.get();

	// Initialize the Projects instance and set it in context
	// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
	projects ??= new Projects(zzz);
	projects_context.set(projects);

	// Synchronize URL params to project state
	$effect.pre(() => {
		projects.set_current_project(zzz.url_params.get_uuid_param('project_id'));
		projects.set_current_domain(zzz.url_params.get_uuid_param('domain_id'));
		projects.set_current_page(zzz.url_params.get_uuid_param('page_id'));
	});
</script>

{@render children()}
