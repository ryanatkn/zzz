<script lang="ts">
	import Multichat_View from '$lib/Multichat_View.svelte';
</script>

<div class="dashboard_chats p_sm">
	<!-- TODO, show the counts of active items for each of the model selector buttons in a snippet here -->
	<div class="panel p_sm">
		<header class="size_xl mb_md">Recent chats</header>
		<button class="w_100 justify_content_start" type="button" disabled>new chat</button>
		<!-- TODO implement data class and markup -->
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
