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
		<div class="flex">
			<button
				type="button"
				class="plain justify_content_start flex_1"
				onclick={() => project_viewmodel.create_new_repo()}
			>
				<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> new repo
			</button>
		</div>

		<nav>
			<ul class="unstyled">
				{#if project_viewmodel.project}
					{#each project_viewmodel.project.repos as repo (repo.id)}
						<li transition:slide>
							<Nav_Link
								href="{base}/projects/{project_viewmodel.project_id}/repos/{repo.id}"
								selected={repo.id === projects.current_repo_id}
								attrs={{title: repo.git_url}}
							>
								<div class="ellipsis row flex_1 pr_xs">
									{#if repo.git_url}
										{repo.git_url.replace(/^https?:\/\/|^git@|\.git$/g, '')}
									{:else}
										[new repo]
									{/if}
								</div>
							</Nav_Link>
						</li>
					{/each}
				{/if}
			</ul>
		</nav>
	{/if}
</aside>
