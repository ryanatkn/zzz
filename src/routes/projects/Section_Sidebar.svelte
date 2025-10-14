<script lang="ts">
	import {resolve} from '$app/paths';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import type {Project, Project_Section} from '$routes/projects/project.svelte.js';

	const {
		project,
		section,
	}: {
		project: Project;
		section: Project_Section;
	} = $props();

	// TODO what else should be here? deployments?
	// is `pages` the wrong way to think about it?
	// what about data?
</script>

<aside class="overflow_y_auto unstyled width_upto_xs p_xs">
	<nav>
		<ul class="unstyled">
			<li>
				<Nav_Link
					href={resolve(`/projects/${project.id}`)}
					selected={section === 'project'}
					show_selected_descendent={false}
				>
					project
				</Nav_Link>
			</li>
			<li>
				<Nav_Link href={resolve(`/projects/${project.id}/pages`)} selected={section === 'pages'}
					>pages</Nav_Link
				>
			</li>
			<li>
				<Nav_Link
					href={resolve(`/projects/${project.id}/domains`)}
					selected={section === 'domains'}
				>
					domains
				</Nav_Link>
			</li>
			<li>
				<Nav_Link href={resolve(`/projects/${project.id}/repos`)} selected={section === 'repos'}>
					repos
				</Nav_Link>
			</li>
			<li>
				<Nav_Link
					href={resolve(`/projects/${project.id}/settings`)}
					selected={section === 'settings'}
				>
					settings
				</Nav_Link>
			</li>
		</ul>
	</nav>
</aside>
