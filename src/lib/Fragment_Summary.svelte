<script lang="ts">
	import type {Prompt_Fragment} from '$lib/prompt.svelte.js';

	interface Props {
		fragment: Prompt_Fragment;
	}
	const {fragment}: Props = $props();
</script>

<div class="flex panel px_sm py_xs3 white_space_nowrap size_sm">
	<div>{fragment.name}</div>
	<div class="pl_md ellipsis">{fragment.content}</div>
</div>
