<script lang="ts">
	import {page} from '$app/state';

	import Nav_Link from '$lib/Nav_Link.svelte';

	interface Props {
		section: 'project' | 'pages' | 'domains' | 'settings';
	}

	const {section}: Props = $props();

	const project_id = $derived(page.params.project_id);
</script>

<aside class="overflow_y_auto unstyled width_xs p_xs">
	<nav>
		<ul class="unstyled">
			<li>
				<Nav_Link
					href="/projects/{project_id}"
					selected={section === 'project'}
					show_selected_descendent={false}
				>
					project
				</Nav_Link>
			</li>
			<li>
				<Nav_Link href="/projects/{project_id}/pages" selected={section === 'pages'}>pages</Nav_Link
				>
			</li>
			<li>
				<Nav_Link href="/projects/{project_id}/domains" selected={section === 'domains'}>
					domains
				</Nav_Link>
			</li>
			<li>
				<Nav_Link href="/projects/{project_id}/settings" selected={section === 'settings'}>
					settings
				</Nav_Link>
			</li>
		</ul>
	</nav>
</aside>
