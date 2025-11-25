<script lang="ts">
	import type {PartUnion} from '$lib/part.svelte.js';
	import XmlTagControls from '$lib/XmlTagControls.svelte';
	import PartStats from '$lib/PartStats.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {get_part_type_glyph} from '$lib/part_helpers.js';
	import PartEditorForText from '$lib/PartEditorForText.svelte';
	import PartContextmenu from '$lib/PartContextmenu.svelte';
	import PartEditorForDiskfile from '$lib/PartEditorForDiskfile.svelte';
	import PartToggleButton from '$lib/PartToggleButton.svelte';
	import PartRemoveButton from '$lib/PartRemoveButton.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';

	const {
		part,
		show_actions = true,
	}: {
		part: PartUnion;
		show_actions?: boolean | undefined;
	} = $props();

	const app = frontend_context.get();
	const {prompts} = app;
</script>

<PartContextmenu {part}>
	<div class="column gap_sm" class:dormant={!part.enabled}>
		<div class="display_flex mb_0 justify_content_space_between">
			<div class="font_size_lg m_0">
				<Glyph glyph={get_part_type_glyph(part)} />&nbsp;
				{part.name}
			</div>
			<div class="display_flex gap_xs">
				<PartToggleButton {part} />
				<PartRemoveButton {part} {prompts} />
			</div>
		</div>

		<div>
			{#if part.type === 'text'}
				<PartEditorForText text_part={part} {show_actions} />
			{:else if part.type === 'diskfile'}
				<PartEditorForDiskfile diskfile_part={part} {show_actions} />
			{/if}
		</div>

		<PartStats {part} />
		<XmlTagControls {part} />
	</div>
</PartContextmenu>
