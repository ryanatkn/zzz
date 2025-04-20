<script lang="ts">
	import {fade, slide} from 'svelte/transition';

	import {GLYPH_ARROW_RIGHT} from '$lib/glyphs.js';
	import type {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import Glyph from '$lib/Glyph.svelte';

	interface Props {
		editor_state: Diskfile_Editor_State;
	}

	const {editor_state}: Props = $props();
</script>

<div class="font_mono size_sm">
	<div class="flex justify_content_space_between">
		<div>
			chars
			{editor_state.original_length}
			{#if editor_state.original_length !== editor_state.current_length}
				<span transition:fade={{duration: 80}}>
					<Glyph glyph={GLYPH_ARROW_RIGHT} />
					{editor_state.current_length}</span
				>{/if}
		</div>
		{#if editor_state.length_diff}
			<div class="white_space_nowrap" transition:slide={{axis: 'x'}}>
				{editor_state.length_diff > 0 ? '+' : ''}{editor_state.length_diff} =
				{editor_state.length_diff > 0 ? '+' : ''}{editor_state.length_diff_percent}%
			</div>
		{/if}
	</div>
	<div class="flex justify_content_space_between">
		<div>
			tokens
			{editor_state.original_token_count}
			{#if editor_state.original_token_count !== editor_state.current_token_count}
				<span transition:fade={{duration: 80}}>
					<Glyph glyph={GLYPH_ARROW_RIGHT} />
					{editor_state.current_token_count}</span
				>{/if}
		</div>
		{#if editor_state.token_diff}
			<div class="white_space_nowrap" transition:slide={{axis: 'x'}}>
				{editor_state.token_diff > 0 ? '+' : ''}{editor_state.token_diff} =
				{editor_state.token_diff > 0 ? '+' : ''}{editor_state.token_diff_percent}%
			</div>
		{/if}
	</div>
</div>
