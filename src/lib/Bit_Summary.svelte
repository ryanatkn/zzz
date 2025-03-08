<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import type {Bit} from '$lib/bit.svelte.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';

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
	class="bit_summary flex justify_content_space_between gap_xs2 size_sm relative panel"
	class:dormant={!bit.enabled}
>
	<div class="progress_bar" style:width="{percent}%"></div>
	<div class="flex_1 pl_sm py_xs3 ellipsis">
		{bit.name}
	</div>
	<div class="controls flex gap_xs2">
		<input
			type="checkbox"
			class="plain compact"
			title="This bit is {bit.enabled ? 'enabled' : 'disabled'} and {bit.enabled
				? ''
				: 'not '}included in the prompt"
			bind:checked={bit.enabled}
		/>
		<Confirm_Button
			onclick={() => {
				prompt.remove_bit(bit.id);
			}}
			attrs={{
				class: 'plain compact',
				title: `Remove bit ${bit.name}`,
			}}
		>
			{GLYPH_REMOVE}
		</Confirm_Button>
	</div>
</div>

<style>
	.progress_bar {
		position: absolute;
		left: 0;
		top: 0;
		height: 100%;
		background: var(--fg_5);
		opacity: var(--fade_6);
		transition: width var(--duration_3) ease-in-out;
		border-radius: var(--radius_xs);
	}

	.controls {
		visibility: hidden;
	}
	.bit_summary:hover .controls {
		visibility: visible;
	}
</style>
