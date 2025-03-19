<script lang="ts">
	import type {Bit_Type} from '$lib/bit.svelte.js';
	import type {Prompts} from '$lib/prompts.svelte.js';
	import Xml_Tag_Controls from '$lib/Xml_Tag_Controls.svelte';
	import Bit_Stats from '$lib/Bit_Stats.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {get_bit_type_glyph} from '$lib/bit_helpers.js';
	import Bit_Editor_Text from '$lib/Bit_Editor_Text.svelte';
	import Bit_Editor_Diskfile from '$lib/Bit_Editor_Diskfile.svelte';
	import Bit_Editor_Sequence from '$lib/Bit_Editor_Sequence.svelte';
	import Bit_Toggle_Button from '$lib/Bit_Toggle_Button.svelte';
	import Bit_Remove_Button from '$lib/Bit_Remove_Button.svelte';

	interface Props {
		bit: Bit_Type;
		prompts: Prompts;
		show_actions?: boolean;
	}

	const {bit, prompts, show_actions = true}: Props = $props();

	const prompt = $derived(prompts.selected);
</script>

<div class="bit_view column gap_sm" class:dormant={!bit.enabled}>
	<div class="flex mb_0 justify_content_space_between">
		<div class="size_lg m_0">
			<span class="mr_xs2"><Glyph_Icon icon={get_bit_type_glyph(bit)} /></span>
			{bit.name}
		</div>
		<div class="flex gap_xs">
			<Bit_Toggle_Button {bit} />
			<Bit_Remove_Button {bit} {prompts} />
		</div>
	</div>

	<!-- Content section - different for each bit type -->
	{#if bit.type === 'text'}
		<Bit_Editor_Text text_bit={bit} {show_actions} />
	{:else if bit.type === 'diskfile'}
		<Bit_Editor_Diskfile diskfile_bit={bit} {show_actions} />
	{:else if bit.type === 'sequence'}
		<Bit_Editor_Sequence sequence_bit={bit} {prompt} />
	{/if}

	<!-- Common controls for all bit types -->
	<Bit_Stats {bit} />
	<Xml_Tag_Controls {bit} />
</div>

<style>
	.dormant {
		opacity: 0.5;
	}
</style>
