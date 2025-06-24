<script lang="ts">
	import type {Snippet} from 'svelte';

	interface Props {
		header: Snippet;
		children: Snippet;
	}

	const {header, children}: Props = $props();
</script>

<div class="display_flex">
	<header class="flex_1">
		{@render header()}
	</header>
	<div>
		{@render children()}
	</div>
</div>
