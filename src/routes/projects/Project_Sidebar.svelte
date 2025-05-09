<script lang="ts">
	import {slide} from 'svelte/transition';
	import {goto} from '$app/navigation';
	import {base} from '$app/paths';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import {projects_context} from '$routes/projects/projects.svelte.js';
	import {GLYPH_ADD} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	const projects = projects_context.get();
</script>

<aside class="h_100 overflow_y_auto unstyled width_xs p_xs">
	<div class="display_flex">
		<button
			type="button"
			class="plain justify_content_start flex_1"
			onclick={() => {
				const project = projects.create_new_project();
				void goto(`${base}/projects/${project.id}`);
			}}
		>
			<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> new project
		</button>
	</div>

	<nav>
		<ul class="unstyled">
			{#each projects.projects as project (project.id)}
				<li transition:slide>
					<Nav_Link
						href="{base}/projects/{project.id}"
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
