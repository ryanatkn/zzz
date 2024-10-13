<script lang="ts">
	import type {Snippet} from 'svelte';

	import Hud_Root from '$lib/Hud_Root.svelte';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();
</script>

<Hud_Root>
	<main>
		{@render children()}
	</main>
</Hud_Root>
