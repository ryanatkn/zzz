<script lang="ts">
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';

	import Glyph from '$lib/Glyph.svelte';
	import {get_glyph_for_action_kind} from '$lib/glyphs.js';
	import type {Action} from '$lib/action.svelte.js';

	const {
		action,
	}: {
		action: Action;
	} = $props();

	// TODO this is all hacky, just proof of concept stuff
</script>

<div class="mb_md">
	<h3 class="mt_md">
		<Glyph glyph={get_glyph_for_action_kind(action.kind)} />
		{action.method}
	</h3>
	<table>
		<tbody class="font_family_mono">
			<tr>
				<td>id</td>
				<td>{action.id}</td>
			</tr>
			<tr>
				<td>created</td>
				<td>
					{action.created_formatted_datetime}
					{action.created_formatted_time}
				</td>
			</tr>
			{#if action.updated_formatted_datetime !== action.created_formatted_datetime}
				<tr>
					<td>updated</td>
					<td>
						{action.updated_formatted_datetime}
						{action.updated_formatted_time}
					</td>
				</tr>
			{/if}
			<tr>
				<td>kind</td>
				<td>{action.kind}</td>
			</tr>
			{#if action.action_event_data?.error}
				<tr>
					<td>error</td>
					<td class="font_family_mono color_c">{JSON.stringify(action.action_event_data.error)}</td>
				</tr>
			{/if}
		</tbody>
	</table>
</div>

<div class="display_flex gap_md mb_sm">
	<Copy_To_Clipboard text={JSON.stringify(action.json, null, 2)} attrs={{class: 'plain'}} />
</div>
<pre
	class="font_family_mono font_size_sm white_space_pre_wrap word_break_break_word p_sm width_100">{JSON.stringify(
		action.json,
		null,
		2,
	)}</pre>
