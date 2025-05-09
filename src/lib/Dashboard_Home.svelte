<script lang="ts">
	import {base} from '$app/paths';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Actions_List from '$lib/Action_List.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import {GLYPH_LOG, GLYPH_PROVIDER, GLYPH_MODEL} from '$lib/glyphs.js';

	const zzz = zzz_context.get();
</script>

<div class="p_lg">
	<div class="sections mt_lg">
		<section class="panel p_md mb_0">
			<div class="mb_lg">
				<a class="font_size_xl font_weight_600" href="{base}/log"><Glyph glyph={GLYPH_LOG} /> log</a
				>
			</div>
			<Actions_List limit={5} attrs={{class: 'mt_sm'}} />
		</section>

		<section class="panel p_md mb_0">
			<div class="mb_lg">
				<a class="font_size_xl font_weight_600" href="{base}/providers"
					><Glyph glyph={GLYPH_PROVIDER} /> providers</a
				>
			</div>
			<div>
				<ul class="unstyled">
					{#each zzz.providers.items as provider (provider.name)}
						<li class="mb_xs">
							<Provider_Link
								{provider}
								icon="svg"
								attrs={{class: 'menu_item row justify_content_start gap_xs'}}
							/>
						</li>
					{:else}
						<p>no providers configured yet</p>
					{/each}
				</ul>
			</div>
		</section>

		<section class="panel p_md mb_0">
			<div class="mb_lg">
				<a class="font_size_xl font_weight_600" href="{base}/models"
					><Glyph glyph={GLYPH_MODEL} /> models</a
				>
			</div>
			<div>
				<ul class="unstyled">
					{#each zzz.models.ordered_by_name as model (model.name)}
						<li class="mb_xs">
							<Model_Link
								{model}
								icon
								attrs={{class: 'menu_item row justify_content_start gap_xs'}}
							/>
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
		grid-template-columns: repeat(auto-fit, minmax(var(--distance_sm), 1fr));
		gap: var(--space_lg);
	}

	.panel {
		min-width: var(--distance_sm);
		max-width: var(--width_md);
		width: 100%;
	}
</style>
