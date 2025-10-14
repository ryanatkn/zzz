<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import Error_Message_Inline from '$lib/Error_Message_Inline.svelte';
	import type {Turn} from '$lib/turn.svelte.js';
	import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';
	import Turn_Contextmenu from '$lib/Turn_Contextmenu.svelte';

	const {
		turn,
	}: {
		turn: Turn;
	} = $props();
</script>

<Turn_Contextmenu {turn}>
	<div
		class="px_sm py_xl"
		class:user={turn.role === 'user'}
		class:assistant={turn.role === 'assistant'}
		class:system={turn.role === 'system'}
		class:dormant={!turn.enabled}
	>
		<div class="white_space_pre_wrap overflow_wrap_break_word">
			<small class="mr_xs font_weight_600" title={turn.created}>@{turn.role}:</small>
			{#if turn.pending}
				<Pending_Animation inline />
			{:else if turn.error_message}
				<Error_Message_Inline>{turn.error_message}</Error_Message_Inline>
			{:else if turn.is_content_loaded}
				{turn.content}
			{:else if turn.parts.length === 0}
				<span class="text_color_4 font_family_mono">missing parts: {turn.part_ids.join(', ')}</span>
			{:else}
				<Error_Message_Inline>{UNKNOWN_ERROR_MESSAGE}</Error_Message_Inline>
			{/if}
		</div>
	</div>
</Turn_Contextmenu>
