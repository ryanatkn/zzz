<script lang="ts">
	import type {Prompt} from '$lib/prompt.svelte.js';

	interface Props {
		prompt: Prompt;
	}

	const {prompt}: Props = $props();
</script>

<div class="pr_md">
	{prompt.name}
</div>
<div class="flex_1 ellipsis">
	{prompt.content_truncated}
</div>
