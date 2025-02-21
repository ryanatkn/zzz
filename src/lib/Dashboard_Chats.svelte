<script lang="ts">
	import Multichat_View from '$lib/Multichat_View.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import {GLYPH_CHAT} from '$lib/constants.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();
</script>

<div class="dashboard_chats p_sm">
	<!-- TODO, show the counts of active items for each of the model selector buttons in a snippet here -->
	<div class="panel p_sm">
		<header class="size_xl mb_md">
			<h1 class="mt_0"><Text_Icon icon={GLYPH_CHAT} /> chats</h1>
		</header>
		<button class="w_100 justify_content_start" type="button" disabled>new chat</button>
		<!-- TODO implement chat data class and markup -->
	</div>
	<!-- TODO select view (tabs?) -->
	{#if zzz.inited_models}
		<Multichat_View />
	{/if}
</div>

<style>
	.dashboard_chats {
		display: flex;
		align-items: start;
		gap: var(--space_md);
	}
</style>
