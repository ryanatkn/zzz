<script lang="ts">
	import type {Snippet} from 'svelte';

	import Hud from '$lib/Hud.svelte';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();
</script>

<Hud>
	<main>
		{@render children()}
	</main>
</Hud>
