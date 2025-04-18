<script lang="ts">
	import {type Snippet} from 'svelte';

	import {projects_context, Projects} from './projects.svelte.js';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	// Initialize the Projects instance and set it in context
	const projects = new Projects();
	projects_context.set(projects);
</script>

{@render children()}
