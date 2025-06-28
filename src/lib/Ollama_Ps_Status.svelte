<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {print_number_with_separators} from '@ryanatkn/belt/print.js';
	import {formatDistance} from 'date-fns';
	import {slide} from 'svelte/transition';

	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_INFO, GLYPH_PAUSE, GLYPH_PLAY} from '$lib/glyphs.js';
	import type {Ollama} from '$lib/ollama.svelte.js';

	interface Props {
		ollama: Ollama;
	}

	const {ollama}: Props = $props();
</script>

<div class="panel p_md width_md mb_md">
	<div class="display_flex justify_content_space_between align_items_center mb_md">
		<h4 class="mt_0 mb_0">
			<Glyph glyph={GLYPH_INFO} />
			running models
		</h4>
		<div class="display_flex align_items_center gap_sm">
			{#if ollama.ps_status === 'pending'}
				<Pending_Animation />
			{/if}
			<button
				type="button"
				class="display_flex align_items_center gap_sm"
				disabled={ollama.ps_status === 'pending'}
				onclick={() => {
					if (ollama.ps_polling_enabled) {
						ollama.stop_ps_polling();
					} else {
						ollama.start_ps_polling();
					}
				}}
			>
				<Glyph glyph={ollama.ps_polling_enabled ? GLYPH_PAUSE : GLYPH_PLAY} />
				<span>
					{ollama.ps_polling_enabled ? 'stop monitoring' : 'start monitoring'}
				</span>
			</button>
		</div>
	</div>

	{#if ollama.running_models.length > 0}
		<ul class="unstyled" transition:slide>
			{#each ollama.running_models as model (model.name)}
				<li class="py_xs3" transition:slide>
					<div
						class="display_flex justify_content_space_between align_items_center p_sm border_radius_xs bg_1"
					>
						<div class="display_flex gap_sm align_items_center">
							<div class="font_weight_600 font_family_mono">{model.name}</div>
							{#if model.size_vram > 0}
								<small>
									VRAM: {print_number_with_separators(model.size_vram + '', ',')}
								</small>
							{/if}
						</div>
						<!-- TODO maybe refactor with derived state -->
						{#if model.expires_at}
							{@const expires_at_date = new Date(model.expires_at)}
							{@const expires_at_ms = expires_at_date.valueOf()}
							<small>
								{#if expires_at_ms > ollama.app.time.now_ms}
									expires {formatDistance(expires_at_date, ollama.app.time.now_ms, {
										addSuffix: true,
									})}
								{:else}
									expired
								{/if}
							</small>
						{/if}
					</div>
				</li>
			{/each}
		</ul>
	{:else}
		<p class="font_size_sm" transition:slide>no models currently loaded</p>
	{/if}
</div>
