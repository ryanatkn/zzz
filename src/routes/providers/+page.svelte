<script lang="ts">
	import {default_agents} from '$lib/config.js';
</script>

<div class="shadow_inset_top_sm p_lg">
	<h1>Providers</h1>
	<aside>TODO add <a href="https://github.com/ollama/ollama-js">Ollama</a></aside>
	<div class="agents_grid">
		{#each default_agents as agent}
			<div class="agent_card">
				<h2 class="agent_name">{agent.title}</h2>
				<div class="agent_id">{agent.name}</div>
				{#if agent.url}
					<div class="agent_stat">
						<a href={agent.url} target="_blank">Docs</a>
					</div>
				{/if}
				{#if agent.icon}
					<div class="agent_stat">
						<img src={agent.icon} alt={`${agent.title} icon`} class="provider_icon" />
					</div>
				{/if}
			</div>
		{/each}
	</div>
</div>

<style>
	.agents_grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--space_lg);
		width: 100%;
		padding: var(--space_md);
	}

	.agent_card {
		background: var(--fg_1);
		border-radius: var(--radius_md);
		padding: var(--space_lg);
	}

	.agent_name {
		font-size: var(--size_lg);
		margin: 0 0 var(--space_sm);
	}

	.agent_id {
		color: var(--text_2);
		margin-bottom: var(--space_sm);
	}

	.agent_stat {
		color: var(--text_2);
		margin-bottom: var(--space_xs);
	}

	.provider_icon {
		max-width: 32px;
		max-height: 32px;
		object-fit: contain;
	}
</style>
