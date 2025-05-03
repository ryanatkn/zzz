<script lang="ts">
	import type {Strip} from '$lib/strip.svelte.js';
	import Bit_Stats from '$lib/Bit_Stats.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {get_bit_type_glyph} from '$lib/bit_helpers.js';
	import Bit_Editor_For_Text from '$lib/Bit_Editor_For_Text.svelte';
	import Contextmenu_Strip from '$lib/Contextmenu_Strip.svelte';
	import Bit_Editor_For_Diskfile from '$lib/Bit_Editor_For_Diskfile.svelte';
	import Bit_Editor_For_Sequence from '$lib/Bit_Editor_For_Sequence.svelte';
	import Bit_Toggle_Button from '$lib/Bit_Toggle_Button.svelte';
	import Bit_Remove_Button from '$lib/Bit_Remove_Button.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	// TODO strips having the bit reference as the source of truth may be the wrong way to go?
	// then the strips would have a copy of the final rendered content,
	// so they can be edited without affecting other data

	interface Props {
		strip: Strip;
		show_actions?: boolean | undefined;
	}

	const {strip, show_actions = true}: Props = $props();

	const {bit} = $derived(strip);

	const zzz = zzz_context.get();
	const {prompts} = zzz;

	const prompt = $derived(prompts.selected);
</script>

<Contextmenu_Strip {strip}>
	{#if bit}
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
		</div>
	{:else}
		<div class="p_sm">
			bit not found: <code>{strip.bit_id}</code>
		</div>
	{/if}
</Contextmenu_Strip>
