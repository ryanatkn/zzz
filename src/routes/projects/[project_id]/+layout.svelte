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
		// Set current IDs from URL params
		projects.set_current_project(page.params.project_id || null);
		projects.set_current_page(page.params.page_id || null);
		projects.set_current_domain(page.params.domain_id || null);
	});
</script>

{@render children()}
