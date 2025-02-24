<script lang="ts">
	import type {Prompt, Prompt_Fragment} from '$lib/prompt.svelte.js';

	interface Props {
		fragment: Prompt_Fragment;
		prompt: Prompt;
	}
	const {fragment, prompt}: Props = $props();

	const total_tokens = $derived(fragment.enabled ? fragment.token_count : 0);
	const percent = $derived(
		total_tokens && prompt.token_count ? (total_tokens / prompt.token_count) * 100 : 0,
	);

	// TODO visuals are very basic

	// TODO BLOCK add controls to the right, starting with enable/disable toggle, maybe remove button, or an edit button that brings up a dialog? so far we've avoided dialogs tho
</script>

<div
	class="flex panel px_sm py_xs3 white_space_nowrap size_sm relative"
	class:dormant={!fragment.enabled}
>
	<div class="progress_bar" style:width="{percent}%"></div>
	<div>{fragment.name}</div>
	<div class="pl_md ellipsis">{fragment.content}</div>
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
