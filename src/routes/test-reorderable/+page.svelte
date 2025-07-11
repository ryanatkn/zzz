<script lang="ts">
	import {Reorderable} from '$lib/reorderable.js';

	const reorderable = new Reorderable();

	const items = $state(['Item 1', 'Item 2', 'Item 3', 'Item 4', 'Item 5']);

	const onreorder = (from_index: number, to_index: number) => {
		console.log('Reordering from', from_index, 'to', to_index);
		const [removed] = items.splice(from_index, 1);
		items.splice(to_index, 0, removed);
	};
</script>

<h1>Test Reorderable</h1>

<ul class="unstyled column gap_m" {@attach reorderable.list({onreorder})}>
	{#each items as item, i (item)}
		<li class="p_m bg_2 radius_m" {@attach reorderable.item({index: i})}>
			{item} (index: {i})
		</li>
	{/each}
</ul>

<style>
	ul {
		max-width: 300px;
		margin: 2rem auto;
	}

	li {
		cursor: move;
		user-select: none;
	}

	li:hover {
		background: var(--bg_3);
	}
</style>
