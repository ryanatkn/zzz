<script lang="ts">
	import type {Snippet} from 'svelte';

	import Hud_Root from '$lib/Hud_Root.svelte';
	import Dashboard from '$lib/Dashboard.svelte';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();
</script>

<div class="p_md">
	<Dashboard />
</div>
<Hud_Root>
	<main>
		{@render children()}
	</main>
</Hud_Root>
