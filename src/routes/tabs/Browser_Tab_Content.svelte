<script lang="ts">
	import type {Snippet} from 'svelte';
	import type {Browser_Tab} from '$routes/tabs/browser.svelte.js';

	interface Props {
		tab: Browser_Tab;
		children: Snippet;
	}

	const {tab, children}: Props = $props();
</script>

{#key tab.refresh_counter}
	{#if tab.type === 'embedded_html'}
		<div class="iframe_container">
			<!-- Using srcdoc to render the HTML content -->
			<iframe title={tab.title} srcdoc={tab.content} sandbox="allow-scripts allow-popups"></iframe>
		</div>
	{:else if tab.type === 'external_url'}
		<div class="iframe_container">
			<iframe title={tab.title} src={tab.url} sandbox="allow-scripts allow-same-origin"></iframe>
		</div>
	{:else}
		<!-- Raw tab content -->
		<div class="p_lg">
			{@render children()}
		</div>
	{/if}
{/key}

<style>
	.iframe_container {
		display: flex; /* fixes a height bug */
		width: 100%;
		height: 100%;
	}

	iframe {
		width: 100%;
		height: 100%;
		border: none;
	}
</style>
