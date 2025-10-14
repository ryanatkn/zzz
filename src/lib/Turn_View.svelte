<script lang="ts">
	import type {Turn} from '$lib/turn.svelte.js';
	import Part_Stats from '$lib/Part_Stats.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {get_part_type_glyph} from '$lib/part_helpers.js';
	import Part_Editor_For_Text from '$lib/Part_Editor_For_Text.svelte';
	import Turn_Contextmenu from '$lib/Turn_Contextmenu.svelte';
	import Part_Editor_For_Diskfile from '$lib/Part_Editor_For_Diskfile.svelte';
	import Part_Toggle_Button from '$lib/Part_Toggle_Button.svelte';
	import Part_Remove_Button from '$lib/Part_Remove_Button.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';

	const {
		turn,
		show_actions = true,
	}: {
		turn: Turn;
		show_actions?: boolean | undefined;
	} = $props();

	const app = frontend_context.get();
	const {prompts} = app;
</script>

<Turn_Contextmenu {turn}>
	{#if turn.parts.length > 0}
		{#each turn.parts as part (part.id)}
			<div class="column gap_sm mb_md" class:dormant={!part.enabled}>
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
			</div>
		{/each}
	{:else}
		<div class="p_sm">
			{#if turn.part_ids.length > 0}
				parts not found: <code>{turn.part_ids.join(', ')}</code>
			{:else}
				no parts in turn
			{/if}
		</div>
	{/if}
</Turn_Contextmenu>
