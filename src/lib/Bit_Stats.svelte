<script lang="ts">
	import type {Bit_Type} from '$lib/bit.svelte.js';
	import Content_Stats from '$lib/Content_Stats.svelte';

	interface Props {
		bit: Bit_Type;
	}

	const {bit}: Props = $props();

	const token_count = $derived(bit.token_count ?? 0);
</script>

<Content_Stats {token_count} />
