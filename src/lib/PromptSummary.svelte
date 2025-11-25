<script lang="ts">
	import type {Prompt} from './prompt.svelte.js';

	const {
		prompt,
	}: {
		prompt: Prompt;
	} = $props();
</script>

<div class="pr_md">
	{prompt.name}
</div>
<div class="flex_1 ellipsis">
	{prompt.content_preview}
</div>
