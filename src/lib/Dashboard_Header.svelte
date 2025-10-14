<script lang="ts">
	import type {Snippet} from 'svelte';

	const {
		header,
		children,
	}: {
		header: Snippet;
		children: Snippet;
	} = $props();
</script>

<div class="display_flex">
	<header class="flex_1">
		{@render header()}
	</header>
	<div>
		{@render children()}
	</div>
</div>
