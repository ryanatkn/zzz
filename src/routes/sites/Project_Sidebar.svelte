<script lang="ts">
	import Nav_Link from '$lib/Nav_Link.svelte';
	import {slide} from 'svelte/transition';
	import {projects_context} from './projects.svelte.js';

	const projects = projects_context.get();
</script>

<aside class="h_100 overflow_y_auto unstyled width_xs p_xs">
	<div class="flex">
		<button
			type="button"
			class="plain justify_content_start flex_1"
			onclick={() => projects.create_new_project()}
		>
			+ new project
		</button>
	</div>

	<nav>
		<ul class="unstyled">
			{#each projects.projects as project (project.id)}
				<li transition:slide>
					<Nav_Link
						href="/sites/{project.id}"
						selected={project.id === projects.current_project_id}
						attrs={{title: project.name}}
					>
						<span class="ellipsis">{project.name}</span>
					</Nav_Link>
				</li>
			{/each}
		</ul>
	</nav>
</aside>
