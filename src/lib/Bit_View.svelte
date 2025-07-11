<script lang="ts">
	import type {Bit_Type} from '$lib/bit.svelte.js';
	import Xml_Tag_Controls from '$lib/Xml_Tag_Controls.svelte';
	import Bit_Stats from '$lib/Bit_Stats.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {get_bit_type_glyph} from '$lib/bit_helpers.js';
	import Bit_Editor_For_Text from '$lib/Bit_Editor_For_Text.svelte';
	import Bit_Contextmenu from '$lib/Bit_Contextmenu.svelte';
	import Bit_Editor_For_Diskfile from '$lib/Bit_Editor_For_Diskfile.svelte';
	import Bit_Editor_For_Sequence from '$lib/Bit_Editor_For_Sequence.svelte';
	import Bit_Toggle_Button from '$lib/Bit_Toggle_Button.svelte';
	import Bit_Remove_Button from '$lib/Bit_Remove_Button.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';

	interface Props {
		bit: Bit_Type;
		show_actions?: boolean | undefined;
	}

	const {bit, show_actions = true}: Props = $props();

	const app = frontend_context.get();
	const {prompts} = app;

	const prompt = $derived(prompts.selected);
</script>

<Bit_Contextmenu {bit}>
	<div class="column gap_sm" class:dormant={!bit.enabled}>
		<div class="display_flex mb_0 justify_content_space_between">
			<div class="font_size_lg m_0">
				<!-- TODO I like the idea of making this glyph the drag handle (but we probably want dynamic tiles first) -->
				<Glyph glyph={get_bit_type_glyph(bit)} attrs={{class: 'mr_xs2'}} />
				{bit.name}
			</div>
			<div class="display_flex gap_xs">
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
</Bit_Contextmenu>
