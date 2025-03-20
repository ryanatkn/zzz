<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import Error_Message from '$lib/Error_Message.svelte';
	import type {Strip} from '$lib/strip.svelte.js';

	interface Props {
		strip: Strip;
	}

	const {strip}: Props = $props();

	// TODO BLOCK link to the bit maybe? require right clicking probably
</script>

<div
	class="p_sm"
	class:user={strip.role === 'user'}
	class:assistant={strip.role === 'assistant'}
	class:system={strip.role === 'system'}
>
	<div class="white_space_pre_wrap overflow_wrap_break_word line_height_md">
		<small class="mr_xs font_weight_600" title={strip.created}>@{strip.role}:</small>
		{#if strip.is_pending}
			<!-- TODO @many Pending_Animation `inline` prop -->
			<Pending_Animation attrs={{style: 'display: inline-flex !important'}} />
		{:else if strip.is_content_loaded}
			{strip.content}
		{:else if strip.bit === null}
			<span class="text_color_4 font_mono">missing bit: {strip.bit_id}</span>
		{:else}
			<Error_Message>unknown error</Error_Message>
		{/if}
	</div>
</div>
