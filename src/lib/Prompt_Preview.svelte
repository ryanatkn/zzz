<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';

	interface Props {
		prompt: Prompt;
	}

	const {prompt}: Props = $props();
</script>

<div class="white_space_pre_wrap overflow_wrap_break_word font_sans size_sm panel px_md py_xs">
	{prompt.content}
</div>
