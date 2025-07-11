<script lang="ts">
	import type {Bit_Union} from '$lib/bit.svelte.js';
	import Content_Stats from '$lib/Content_Stats.svelte';

	interface Props {
		bit: Bit_Union;
	}

	const {bit}: Props = $props();

	const token_count = $derived(bit.token_count ?? 0);
</script>

<Content_Stats {token_count} />
