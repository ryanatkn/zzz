<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Bit_Union} from '$lib/bit.svelte.js';

	const {
		bit,
		attrs,
	}: {
		bit: Bit_Union;
		attrs?: SvelteHTMLElements['input'] | undefined;
	} = $props();
</script>

<input
	type="checkbox"
	class="plain compact"
	title="this bit is {bit.enabled ? 'enabled' : 'disabled'} and {bit.enabled
		? ''
		: 'not '}included in the prompt"
	bind:checked={bit.enabled}
	{...attrs}
/>
