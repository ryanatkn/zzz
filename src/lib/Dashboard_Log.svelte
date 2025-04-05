<script lang="ts">
	import Payload_List from '$lib/Payload_List.svelte';
	import Payload_Detail from '$lib/Payload_Detail.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_LOG} from '$lib/glyphs.js';
	import type {Payload} from '$lib/payload.svelte.js';

	let selected_payload: Payload | null = $state(null);
</script>

<div class="column p_lg h_100">
	<h1><Glyph icon={GLYPH_LOG} /> log</h1>

	<div
		class="flex_1 grid mt_md overflow_hidden"
		style:grid-template-columns="320px 1fr"
		style:gap="var(--space_md)"
	>
		<div class="overflow_auto border_right">
			<Payload_List
				limit={100}
				selected_payload_id={selected_payload?.id}
				onselect={(payload) => {
					selected_payload = payload;
				}}
			/>
		</div>

		<div class="panel p_md overflow_auto h_100">
			{#if selected_payload}
				<Payload_Detail payload={selected_payload} />
			{:else}
				<div class="flex align_items_center justify_content_center h_100">
					<p>Select a payload from the list to view its details</p>
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
	.border_right {
		border-right: 1px solid var(--color_border);
	}
</style>
