<script lang="ts">
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Tape} from '$lib/tape.svelte.js';

	const {
		tape,
		attrs,
	}: {
		tape: Tape;
		attrs?: SvelteHTMLElements['input'] | undefined;
	} = $props();
</script>

<input
	type="checkbox"
	class="plain compact"
	style:height="auto"
	title="this tape is {tape.enabled ? 'enabled' : 'disabled'} and {tape.enabled
		? ''
		: 'not '}included in the chat"
	bind:checked={tape.enabled}
	{...attrs}
/>
