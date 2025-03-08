<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';

	interface Props {
		prompt: Prompt;
	}

	const {prompt}: Props = $props();
</script>

<div class="white_space_pre_wrap overflow_wrap_break_word font_sans size_sm fg_1 px_md py_xs">
	{prompt.content}
</div>
