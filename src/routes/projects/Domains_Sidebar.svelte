<script lang="ts">
	import {slide} from 'svelte/transition';
	import {base} from '$app/paths';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import {projects_context} from './projects.svelte.js';
	import {GLYPH_ADD} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	const projects = projects_context.get();

	const controller = $derived(projects.current_project_controller);
</script>

<aside class="h_100 overflow_y_auto unstyled width_xs p_xs">
	{#if controller}
		<div class="flex">
			<button
				type="button"
				class="plain justify_content_start flex_1"
				onclick={() => controller.create_new_domain()}
			>
				<Glyph text={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> new domain
			</button>
		</div>

		<nav>
			<ul class="unstyled">
				{#if controller.project}
					{#each controller.project.domains as domain (domain.id)}
						<li transition:slide>
							<Nav_Link
								href="{base}/projects/{controller.project_id}/domains/{domain.id}"
								selected={domain.id === projects.current_domain_id}
								attrs={{title: domain.name}}
							>
								<div class="ellipsis row flex_1 pr_xs">{domain.name || '[new domain]'}</div>
								<span
									class="status_dot {domain.status === 'active'
										? 'status_active'
										: domain.status === 'pending'
											? 'status_pending'
											: 'status_inactive'}"
								></span>
							</Nav_Link>
						</li>
					{/each}
				{/if}
			</ul>
		</nav>
	{/if}
</aside>

<style>
	.status_dot {
		display: inline-block;
		width: 7px;
		height: 7px;
		border-radius: 50%;
		flex-shrink: 0;
	}

	.status_active {
		background-color: var(--color_a_5);
	}

	.status_pending {
		background-color: var(--color_e_5);
	}

	.status_inactive {
		background-color: var(--text_color_5);
	}
</style>
