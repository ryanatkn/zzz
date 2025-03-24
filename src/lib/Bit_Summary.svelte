<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import type {Bit_Type} from '$lib/bit.svelte.js';
	import Bit_Toggle_Button from '$lib/Bit_Toggle_Button.svelte';
	import Bit_Remove_Button from '$lib/Bit_Remove_Button.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {get_bit_type_glyph} from '$lib/bit_helpers.js';

	interface Props {
		bit: Bit_Type;
		prompt?: Prompt | undefined;
	}
	const {bit, prompt}: Props = $props();

	const total_chars = $derived(bit.enabled ? bit.length : 0);
	// TODO bug here where the xml tag is not taken into account, so they add up to less than 100% as calculated
	const percent = $derived(total_chars && prompt?.length ? (total_chars / prompt.length) * 100 : 0);

	// TODO visuals are very basic
</script>

<div
	class="bit_summary flex justify_content_space_between gap_xs2 size_sm relative panel"
	class:dormant={!bit.enabled}
>
	<div class="progress_bar" style:width="{percent}%"></div>
	<div class="flex_1 pl_sm py_xs3 ellipsis">
		<span class="mr_xs2"><Glyph_Icon icon={get_bit_type_glyph(bit)} /></span>
		{bit.name}
		{bit.content_preview}
	</div>
	<div class="controls flex gap_xs2">
		<Bit_Toggle_Button {bit} />
		<Bit_Remove_Button {bit} {prompt} />
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
