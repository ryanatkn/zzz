<script lang="ts">
	import Nav_Link from '$lib/Nav_Link.svelte';
	import {projects_context} from './projects.svelte.js';
	import {slide} from 'svelte/transition';

	const projects = projects_context.get();
	const controller = projects.get_project_controller();
</script>

<aside class="h_100 overflow_y_auto unstyled width_xs p_xs">
	<div class="flex">
		<button
			type="button"
			class="plain justify_content_start flex_1"
			onclick={() => controller.create_new_page()}
		>
			+ new page
		</button>
	</div>

	<nav>
		<ul class="unstyled">
			{#if controller.project}
				{#each controller.project.pages as page (page.id)}
					<li transition:slide>
						<Nav_Link
							href="/sites/{controller.project_id}/pages/{page.id}"
							selected={page.id === projects.current_page_id}
							attrs={{title: page.title}}
						>
							<span class="ellipsis">{page.title}</span>
						</Nav_Link>
					</li>
				{/each}
			{/if}
		</ul>
	</nav>
</aside>
