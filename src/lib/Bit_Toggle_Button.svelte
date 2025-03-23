<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Bit_Type} from '$lib/bit.svelte.js';

	interface Props {
		bit: Bit_Type;
		attrs?: SvelteHTMLElements['input'] | undefined;
	}

	const {bit, attrs = {}}: Props = $props();
</script>

<input
	type="checkbox"
	class="plain compact {attrs.class || ''}"
	title="this bit is {bit.enabled ? 'enabled' : 'disabled'} and {bit.enabled
		? ''
		: 'not '}included in the prompt"
	bind:checked={bit.enabled}
	{...attrs}
/>
