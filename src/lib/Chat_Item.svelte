<script lang="ts">
	import {format} from 'date-fns';

	import type {
		Completion_Thread,
		Completion_Thread_History_Item,
	} from '$lib/completion_thread.svelte.js';
	import Completion_Thread_Summary from '$lib/Completion_Thread_Summary.svelte';
	import type {Provider} from '$lib/provider.svelte.js';

	interface Props {
		provider: Provider;
		completion_thread: Completion_Thread;
		item: Completion_Thread_History_Item;
	}

	const {provider, completion_thread, item}: Props = $props();

	// TODO BLOCK currently unused
	$inspect('Chat_Item item', item);
</script>

<li>
	<!--
	<div class="signature">
		<Actor_Avatar {actor} show_name={false} />
	</div> -->
	<div class="content">
		<div class="signature">
			<!-- <Actor_Avatar {actor} show_icon={false} /> -->
			<small>{format(item.completion_request.created, 'MMM d, p')}</small>
		</div>
		<div class="formatted">
			<Completion_Thread_Summary {provider} {completion_thread} />
		</div>
	</div>
</li>

<style>
	li {
		align-items: flex-start;
		padding: var(--space_xs);
		/* TODO experiment with a border color instead of bg */
		background-color: hsl(var(--hue), var(--tint_saturation), 89%);
	}
	/* TODO hacky */
	:global(.dark) li {
		background-color: hsl(var(--hue), var(--tint_saturation), 11%);
	}
	.signature {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}
	.content {
		padding-left: var(--space_md);
		flex: 1;
	}
	.formatted {
		/* the bottom padding prevents chars like y and g from being cut off */
		padding-bottom: var(--space_xs);
	}
</style>
