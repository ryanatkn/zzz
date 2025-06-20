<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import Error_Message from '$lib/Error_Message.svelte';
	import type {Strip} from '$lib/strip.svelte.js';
	import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';
	import Contextmenu_Strip from '$lib/Contextmenu_Strip.svelte';

	interface Props {
		strip: Strip;
	}

	const {strip}: Props = $props();
</script>

<Contextmenu_Strip {strip}>
	<div
		class="px_sm py_xl"
		class:user={strip.role === 'user'}
		class:assistant={strip.role === 'assistant'}
		class:system={strip.role === 'system'}
		class:dormant={strip.bit && !strip.bit.enabled}
	>
		<div class="white_space_pre_wrap overflow_wrap_break_word">
			<small class="mr_xs font_weight_600" title={strip.created}>@{strip.role}:</small>
			{#if strip.pending}
				<!-- TODO @many Pending_Animation `inline` prop -->
				<Pending_Animation inline />
			{:else if strip.is_content_loaded}
				{strip.content}
			{:else if strip.bit === null}
				<span class="text_color_4 font_family_mono">missing bit: {strip.bit_id}</span>
			{:else}
				<Error_Message>{UNKNOWN_ERROR_MESSAGE}</Error_Message>
			{/if}
		</div>
	</div>
</Contextmenu_Strip>
