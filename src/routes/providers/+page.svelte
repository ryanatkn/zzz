<script lang="ts">
	import {default_providers} from '$lib/config.js';
</script>

<div class="p_lg">
	<h1>Providers</h1>
	<aside>TODO add <a href="https://github.com/mlc-ai/web-llm">WebLLM</a></aside>
	<aside>TODO add <a href="https://github.com/ollama/ollama-js">Ollama</a></aside>
	<div class="providers_grid">
		{#each default_providers as provider}
			<div class="provider_card">
				<h2 class="provider_name">{provider.title}</h2>
				<div class="provider_id">{provider.name}</div>
				{#if provider.url}
					<div class="provider_stat">
						<a href={provider.url} target="_blank">Docs</a>
					</div>
				{/if}
				{#if provider.icon}
					<div class="provider_stat">
						<img src={provider.icon} alt={`${provider.title} icon`} class="provider_icon" />
					</div>
				{/if}
			</div>
		{/each}
	</div>
</div>

<style>
	.providers_grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space_lg);
		width: 100%;
		padding: var(--space_md);
	}

	.provider_card {
		background: var(--fg_1);
		border-radius: var(--radius_md);
		padding: var(--space_lg);
	}

	.provider_name {
		font-size: var(--size_lg);
		margin: 0 0 var(--space_sm);
	}

	.provider_id {
		color: var(--text_2);
		margin-bottom: var(--space_sm);
	}

	.provider_stat {
		color: var(--text_2);
		margin-bottom: var(--space_xs);
	}

	.provider_icon {
		max-width: 32px;
		max-height: 32px;
		object-fit: contain;
	}
</style>
