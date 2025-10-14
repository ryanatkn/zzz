<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';
	import type {Part_Union} from '$lib/part.svelte.js';
	import Part_Toggle_Button from '$lib/Part_Toggle_Button.svelte';
	import Part_Remove_Button from '$lib/Part_Remove_Button.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import Part_Contextmenu from '$lib/Part_Contextmenu.svelte';
	import {get_part_type_glyph} from '$lib/part_helpers.js';

	const {
		part,
		prompt,
	}: {
		part: Part_Union;
		prompt?: Prompt | undefined;
	} = $props();

	const total_chars = $derived(part.enabled ? part.length : 0);
	// TODO bug here where the xml tag is not taken into account, so they add up to less than 100% as calculated
	const percent = $derived(total_chars && prompt?.length ? (total_chars / prompt.length) * 100 : 0);

	// TODO visuals are very basic
</script>

<Part_Contextmenu {part}>
	<div
		class="part_summary display_flex justify_content_space_between gap_xs2 font_size_sm position_relative panel"
		class:dormant={!part.enabled}
	>
		<div class="progress_bar" style:width="{percent}%"></div>
		<div class="flex_1 pl_sm py_xs3 ellipsis">
			<Glyph glyph={get_part_type_glyph(part)} />&nbsp;
			{part.name}
			{part.content_preview}
		</div>
		<div class="controls display_flex gap_xs2">
			<Part_Toggle_Button {part} />
			<Part_Remove_Button {part} {prompt} />
		</div>
	</div>
</Part_Contextmenu>

<style>
	.progress_bar {
		position: absolute;
		left: 0;
		top: 0;
		height: 100%;
		background: var(--fg_5);
		opacity: 10%;
		transition: width var(--duration_3) ease-in-out;
		border-radius: var(--border_radius_xs);
	}

	.controls {
		visibility: hidden;
	}
	.part_summary:hover .controls {
		visibility: visible;
	}
</style>
