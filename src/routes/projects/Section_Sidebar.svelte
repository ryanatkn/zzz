<script lang="ts">
	import {base} from '$app/paths';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import type {Project, Project_Section} from '$routes/projects/project.svelte.js';

	interface Props {
		project: Project;
		section: Project_Section;
	}

	const {project, section}: Props = $props();
</script>

<aside class="overflow_y_auto unstyled width_xs p_xs">
	<nav>
		<ul class="unstyled">
			<li>
				<Nav_Link
					href="{base}/projects/{project.id}"
					selected={section === 'project'}
					show_selected_descendent={false}
				>
					project
				</Nav_Link>
			</li>
			<li>
				<Nav_Link href="{base}/projects/{project.id}/pages" selected={section === 'pages'}
					>pages</Nav_Link
				>
			</li>
			<li>
				<Nav_Link href="{base}/projects/{project.id}/domains" selected={section === 'domains'}>
					domains
				</Nav_Link>
			</li>
			<li>
				<Nav_Link href="{base}/projects/{project.id}/repos" selected={section === 'repos'}>
					repos
				</Nav_Link>
			</li>
			<li>
				<Nav_Link href="{base}/projects/{project.id}/settings" selected={section === 'settings'}>
					settings
				</Nav_Link>
			</li>
		</ul>
	</nav>
</aside>
