<script lang="ts">
	import {slide} from 'svelte/transition';
	import {base} from '$app/paths';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import {projects_context} from '$routes/projects/projects.svelte.js';
	import {GLYPH_ADD} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	const projects = projects_context.get();

	const project_viewmodel = $derived(projects.current_project_viewmodel);
</script>

<aside class="h_100 overflow_y_auto unstyled width_xs p_xs">
	{#if project_viewmodel}
		<div class="display_flex">
			<button
				type="button"
				class="plain justify_content_start flex_1"
				onclick={() => project_viewmodel.create_new_page()}
			>
				<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> new page
			</button>
		</div>

		<nav>
			<ul class="unstyled">
				{#if project_viewmodel.project}
					{#each project_viewmodel.project.pages as page (page.id)}
						<li transition:slide>
							<Nav_Link
								href="{base}/projects/{project_viewmodel.project_id}/pages/{page.id}"
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
	{/if}
</aside>
