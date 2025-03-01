<script lang="ts">
	import {zzz_context} from '$lib/zzz.svelte.js';
	import Messages_List from '$lib/Messages_List.svelte';
	import Text_Icon from '$lib/Text_Icon.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';

	const zzz = zzz_context.get();
</script>

<div class="p_lg">
	<h1>Welcome to zzz</h1>
	<p>AI chat interface and playground</p>

	<div class="sections mt_lg">
		<section class="panel p_md">
			<h2><Text_Icon icon="📨" /> Recent Messages</h2>
			<Messages_List limit={5} class_name="mt_sm" />
			<div class="mt_md text_align_center">
				<a href="/messages">View All Messages</a>
			</div>
		</section>

		<section class="panel p_md">
			<h2><Text_Icon icon={zzz.providers.items.length > 0 ? '🤖' : '⚙️'} /> Providers</h2>
			<div class="mt_sm">
				{#if zzz.providers.items.length === 0}
					<p>No providers configured yet.</p>
				{:else}
					<ul class="unstyled">
						{#each zzz.providers.items as provider (provider.name)}
							<li class="mb_xs provider-item">
								<Provider_Link {provider} icon="svg" attrs={{class: 'provider-link'}} />
							</li>
						{/each}
					</ul>
				{/if}
				<div class="mt_md text_align_center">
					<a href="/providers">View All Providers</a>
				</div>
			</div>
		</section>
	</div>
</div>

<style>
	.sections {
		display: grid;
		grid-template-columns: 1fr;
		gap: var(--space_lg);
	}

	@media (min-width: 768px) {
		.sections {
			grid-template-columns: repeat(2, 1fr);
		}
	}
</style>
