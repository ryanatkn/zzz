<script lang="ts">
	import Multichat_View from '$lib/Multichat_View.svelte';
	import Unicode_Icon from '$lib/Unicode_Icon.svelte';
	import {SYMBOL_CHAT} from '$lib/constants.js';
</script>

<div class="dashboard_chats p_sm">
	<!-- TODO, show the counts of active items for each of the model selector buttons in a snippet here -->
	<div class="panel p_sm">
		<header class="size_xl mb_md"><Unicode_Icon icon={SYMBOL_CHAT} /> Recent chats</header>
		<button class="w_100 justify_content_start" type="button" disabled>new chat</button>
		<!-- TODO implement chat data class and markup -->
	</div>
	<!-- TODO select view (tabs?) -->
	<Multichat_View />
</div>

<style>
	.dashboard_chats {
		display: flex;
		align-items: start;
		gap: var(--space_md);
	}
</style>
