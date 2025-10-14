<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Part_Union} from '$lib/part.svelte.js';

	const {
		part,
		attrs,
	}: {
		part: Part_Union;
		attrs?: SvelteHTMLElements['input'] | undefined;
	} = $props();
</script>

<input
	type="checkbox"
	class="plain compact"
	title="this part is {part.enabled ? 'enabled' : 'disabled'} and {part.enabled
		? ''
		: 'not '}included in the prompt"
	bind:checked={part.enabled}
	{...attrs}
/>
