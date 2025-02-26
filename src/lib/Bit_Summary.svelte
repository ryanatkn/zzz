<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import type {Bit} from '$lib/bit.svelte.js';

	interface Props {
		bit: Bit;
		prompt: Prompt;
	}
	const {bit, prompt}: Props = $props();

	const total_chars = $derived(bit.enabled ? bit.content.length : 0);
	// TODO bug here where the xml tag is not taken into account, so they add up to less than 100% as calculated
	const percent = $derived(
		total_chars && prompt.content.length ? (total_chars / prompt.content.length) * 100 : 0,
	);

	// TODO visuals are very basic

	// TODO BLOCK add controls to the right, starting with enable/disable toggle, maybe remove button, or an edit button that brings up a dialog? so far we've avoided dialogs tho
</script>

<div
	class="flex panel px_sm py_xs3 white_space_nowrap size_sm relative"
	class:dormant={!bit.enabled}
>
	<div class="progress_bar" style:width="{percent}%"></div>
	<div>{bit.name}</div>
	<div class="pl_md ellipsis">{bit.content}</div>
</div>

<style>
	.progress_bar {
		position: absolute;
		left: 0;
		top: 0;
		height: 100%;
		background: var(--fg_5);
		opacity: 0.1;
		transition: width 200ms ease-in-out;
	}
</style>
