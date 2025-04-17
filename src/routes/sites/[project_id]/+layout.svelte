<script lang="ts">
	import {page} from '$app/state';
	import type {Snippet} from 'svelte';

	import {projects_context} from '../projects.svelte.js';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	const projects = projects_context.get();

	// Use $effect.pre to synchronize URL params to project state
	$effect.pre(() => {
		const project_id = page.params.project_id;
		const page_id = page.params.page_id;
		const domain_id = page.params.domain_id;

		// Set current IDs from URL params
		projects.set_current_project(project_id);

		if (page_id) {
			projects.set_current_page(page_id);
		}

		if (domain_id) {
			projects.set_current_domain(domain_id);
		}
	});
</script>

{@render children()}
