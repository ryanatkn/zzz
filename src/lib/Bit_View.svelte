<script lang="ts">
	import type {Bit_Type} from '$lib/bit.svelte.js';
	import Xml_Tag_Controls from '$lib/Xml_Tag_Controls.svelte';
	import Bit_Stats from '$lib/Bit_Stats.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {get_bit_type_glyph} from '$lib/bit_helpers.js';
	import Bit_Editor_For_Text from '$lib/Bit_Editor_For_Text.svelte';
	import Contextmenu_Bit from '$lib/Contextmenu_Bit.svelte';
	import Bit_Editor_For_Diskfile from '$lib/Bit_Editor_For_Diskfile.svelte';
	import Bit_Editor_For_Sequence from '$lib/Bit_Editor_For_Sequence.svelte';
	import Bit_Toggle_Button from '$lib/Bit_Toggle_Button.svelte';
	import Bit_Remove_Button from '$lib/Bit_Remove_Button.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		bit: Bit_Type;
		show_actions?: boolean | undefined;
	}

	const {bit, show_actions = true}: Props = $props();

	const zzz = zzz_context.get();
	const {prompts} = zzz;

	const prompt = $derived(prompts.selected);
</script>

<Contextmenu_Bit {bit}>
	<div class="column gap_sm" class:dormant={!bit.enabled}>
		<div class="flex mb_0 justify_content_space_between">
			<div class="size_lg m_0">
				<span class="mr_xs2"><Glyph icon={get_bit_type_glyph(bit)} /></span>
				{bit.name}
			</div>
			<div class="flex gap_xs">
				<Bit_Toggle_Button {bit} />
				<Bit_Remove_Button {bit} {prompts} />
			</div>
		</div>

		<!-- Content section - different for each bit type -->
		<div>
			{#if bit.type === 'text'}
				<Bit_Editor_For_Text text_bit={bit} {show_actions} />
			{:else if bit.type === 'diskfile'}
				<Bit_Editor_For_Diskfile diskfile_bit={bit} {show_actions} />
			{:else if bit.type === 'sequence'}
				<Bit_Editor_For_Sequence sequence_bit={bit} {prompt} />
			{/if}
		</div>

		<!-- Common controls for all bit types -->
		<Bit_Stats {bit} />
		<Xml_Tag_Controls {bit} />
	</div>
</Contextmenu_Bit>
