<script lang="ts">
	import type {Snippet} from 'svelte';

	import type {Browser_Tab} from '$routes/tabs/browser_tab.svelte.js';

	const {
		tab,
		children,
	}: {
		tab: Browser_Tab;
		children: Snippet;
	} = $props();

	// Function to extract title from iframe content
	function handle_iframe_load(event: Event): void {
		const iframe = event.target as HTMLIFrameElement;
		try {
			// Only works for same-origin content due to CORS
			const title = iframe.contentDocument?.title;
			if (title?.trim() && title !== tab.title) {
				tab.title = title.trim();
			}
		} catch (error) {
			// Will fail for cross-origin content
			console.log('Unable to access iframe content:', error);
		}
	}
</script>

{#key tab.refresh_counter}
	{#if tab.type === 'embedded_html'}
		<div class="iframe_container">
			<!-- Using srcdoc to render the HTML content -->
			<iframe
				title={tab.title}
				srcdoc={tab.content}
				sandbox="allow-scripts allow-popups"
				onload={handle_iframe_load}
			></iframe>
		</div>
	{:else if tab.type === 'external_url'}
		<div class="iframe_container">
			<iframe
				title={tab.title}
				src={tab.url}
				sandbox="allow-scripts allow-same-origin"
				onload={handle_iframe_load}
			></iframe>
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
