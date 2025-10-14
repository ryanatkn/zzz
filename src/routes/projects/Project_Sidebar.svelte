<script lang="ts">
	import {slide} from 'svelte/transition';
	import {goto} from '$app/navigation';
	import {resolve} from '$app/paths';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import {projects_context} from '$routes/projects/projects.svelte.js';
	import {GLYPH_ADD} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	const projects = projects_context.get();
</script>

<aside class="height_100 overflow_y_auto unstyled width_upto_xs p_xs">
	<div class="display_flex">
		<button
			type="button"
			class="plain justify_content_start flex_1"
			onclick={() => {
				const project = projects.create_new_project();
				void goto(resolve(`/projects/${project.id}`));
			}}
		>
			<Glyph glyph={GLYPH_ADD} />&nbsp; new project
		</button>
	</div>

	<nav>
		<ul class="unstyled">
			{#each projects.projects as project (project.id)}
				<li transition:slide>
					<Nav_Link
						href={resolve(`/projects/${project.id}`)}
						selected={project.id === projects.current_project_id}
						title={project.name}
					>
						<span class="ellipsis">{project.name}</span>
					</Nav_Link>
				</li>
			{/each}
		</ul>
	</nav>

	<aside title="huh I might take quality vibecoded PRs, but probably in a new repo">
		⚠️ <small>speculative demo</small> ⚠️
	</aside>
</aside>
