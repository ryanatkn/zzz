<script lang="ts">
	import type {Chat_Message} from '$lib/chat_message.svelte.js';

	interface Props {
		message: Chat_Message;
	}

	const {message}: Props = $props();
</script>

<div
	class="p_sm"
	class:user={message.role === 'user'}
	class:assistant={message.role === 'assistant'}
	class:system={message.role === 'system'}
>
	<div class="white_space_pre_wrap overflow_wrap_break_word line_height_md">
		<small class="mb_xs font_weight_600" title={message.created}>@{message.role}:</small>
		{message.content}
	</div>
</div>

<style>
	.user {
		border-left: 3px solid var(--blue_9);
	}
	.assistant {
		border-left: 3px solid var(--green_9);
		background-color: var(--bg_2);
	}
	.system {
		border-left: 3px solid var(--gray_9);
	}
</style>
