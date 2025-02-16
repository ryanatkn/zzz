<script lang="ts">
	import Chat_Item from '$lib/Chat_Item.svelte';

	interface Props {
		items: Array<any>; // TODO BLOCK
	}

	const {items}: Props = $props();

	let text = $state('');

	const create_cell = async () => {
		const content = text.trim(); // TODO parse to trim? regularize step?

		if (!content) return;
		// await actions.create_cell({
		// 	acting: $acting.id,
		// 	spec: {
		// 		list: $space.directory_id,
		// 		data: {content},
		// 	},
		// });
		text = '';
	};

	const onsubmit = async () => {
		await create_cell();
	};

	// TODO BLOCK extract the Pending_Animation, maybe to `Query`
</script>

<div class="chat">
	<div class="items">
		<!-- {#if query && items} -->
		<ul>
			{#each items as item (item)}
				<Chat_Item {item} />
			{/each}
		</ul>
		<!-- <Load_More_Button {query} /> -->
		<!-- {:else}
			<Pending_Animation />
		{/if} -->
	</div>
	<input placeholder=">" {onsubmit} bind:value={text} />
</div>

<style>
	.chat {
		display: flex;
		flex-direction: column;
		flex: 1;
		overflow: hidden; /* make the content scroll */
	}
	.items {
		max-width: var(--width_md);
		overflow: auto;
		flex: 1;
		display: flex;
		/* makes scrolling start at the bottom */
		flex-direction: column-reverse;
	}
</style>
