<script lang="ts">
	import {base} from '$app/paths';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Messages_List from '$lib/Messages_List.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import {GLYPH_MESSAGE, GLYPH_PROVIDER, GLYPH_MODEL} from '$lib/glyphs.js';

	const zzz = zzz_context.get();

	// TODO BLOCK the messages list below should be links to the /messages?id=... page (or whatever URL structure)
</script>

<div class="p_lg">
	<h1>home</h1>
	<div class="sections mt_lg">
		<section class="panel p_md mb_0">
			<div class="mb_lg">
				<a class="size_xl font_weight_500" href="{base}/messages"
					><Glyph_Icon icon={GLYPH_MESSAGE} /> recent messages</a
				>
			</div>
			<Messages_List limit={5} attrs={{class: 'mt_sm'}} />
		</section>

		<section class="panel p_md mb_0">
			<div class="mb_lg">
				<a class="size_xl font_weight_500" href="{base}/providers"
					><Glyph_Icon icon={GLYPH_PROVIDER} /> providers</a
				>
			</div>
			<div>
				<ul class="unstyled">
					{#each zzz.providers.items as provider (provider.name)}
						<li class="mb_xs">
							<span class="menu_item">
								<Provider_Link {provider} icon="svg" attrs={{class: 'row gap_xs'}} />
							</span>
						</li>
					{:else}
						<p>No providers configured yet.</p>
					{/each}
				</ul>
			</div>
		</section>

		<section class="panel p_md mb_0">
			<div class="mb_lg">
				<a class="size_xl font_weight_500" href="{base}/models"
					><Glyph_Icon icon={GLYPH_MODEL} /> models</a
				>
			</div>
			<div>
				<ul class="unstyled">
					{#each zzz.models.items as model (model.name)}
						<li class="mb_xs">
							<span class="menu_item">
								<Model_Link {model} icon attrs={{class: 'row gap_xs'}} />
							</span>
						</li>
					{:else}
						<p>No models available yet.</p>
					{/each}
				</ul>
			</div>
		</section>
	</div>
</div>

<style>
	.sections {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(var(--width_sm), 1fr));
		gap: var(--space_lg);
	}

	.panel {
		min-width: var(--width_sm);
		max-width: var(--width_md);
		width: 100%;
	}

	.menu_item {
		display: flex;
		justify-content: space-between;
		align-items: center;
		width: 100%;
	}
</style>
