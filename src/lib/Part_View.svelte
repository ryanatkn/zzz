<script lang="ts">
	import type {Part_Union} from '$lib/part.svelte.js';
	import Xml_Tag_Controls from '$lib/Xml_Tag_Controls.svelte';
	import Part_Stats from '$lib/Part_Stats.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {get_part_type_glyph} from '$lib/part_helpers.js';
	import Part_Editor_For_Text from '$lib/Part_Editor_For_Text.svelte';
	import Part_Contextmenu from '$lib/Part_Contextmenu.svelte';
	import Part_Editor_For_Diskfile from '$lib/Part_Editor_For_Diskfile.svelte';
	import Part_Toggle_Button from '$lib/Part_Toggle_Button.svelte';
	import Part_Remove_Button from '$lib/Part_Remove_Button.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';

	const {
		part,
		show_actions = true,
	}: {
		part: Part_Union;
		show_actions?: boolean | undefined;
	} = $props();

	const app = frontend_context.get();
	const {prompts} = app;
</script>

<Part_Contextmenu {part}>
	<div class="column gap_sm" class:dormant={!part.enabled}>
		<div class="display_flex mb_0 justify_content_space_between">
			<div class="font_size_lg m_0">
				<Glyph glyph={get_part_type_glyph(part)} />&nbsp;
				{part.name}
			</div>
			<div class="display_flex gap_xs">
				<Part_Toggle_Button {part} />
				<Part_Remove_Button {part} {prompts} />
			</div>
		</div>

		<div>
			{#if part.type === 'text'}
				<Part_Editor_For_Text text_part={part} {show_actions} />
			{:else if part.type === 'diskfile'}
				<Part_Editor_For_Diskfile diskfile_part={part} {show_actions} />
			{/if}
		</div>

		<Part_Stats {part} />
		<Xml_Tag_Controls {part} />
	</div>
</Part_Contextmenu>
