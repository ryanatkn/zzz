<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {formatDistance} from 'date-fns';
	import {slide} from 'svelte/transition';

	import Glyph from '$lib/Glyph.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import {GLYPH_DISCONNECT, GLYPH_INFO, GLYPH_PAUSE, GLYPH_PLAY} from '$lib/glyphs.js';
	import type {Ollama} from '$lib/ollama.svelte.js';
	import {format_bytes} from '$lib/format_helpers.js';

	const {
		ollama,
	}: {
		ollama: Ollama;
	} = $props();

	// TODO this should show "running" models as being actively doing inference, otherwise "loaded"
</script>

<div class="panel p_md width_upto_md">
	<div class="display_flex justify_content_space_between align_items_center mb_md">
		<h4 class="mt_0 mb_0">active models</h4>
		<div class="display_flex align_items_center gap_sm">
			{#if ollama.ps_status === 'pending'}
				<Pending_Animation />
			{/if}
			<button
				type="button"
				class="plain align_items_center gap_sm"
				disabled={ollama.ps_status === 'pending'}
				title="polls Ollama continuously for the status of running models"
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
					{ollama.ps_polling_enabled ? 'stop' : 'start'} monitoring
				</span>
			</button>
		</div>
	</div>

	{#if ollama.running_models.length > 0}
		<ul class="unstyled" transition:slide>
			{#each ollama.running_models as item (item.name)}
				{@const model = ollama.model_by_name.get(item.name)}
				<li class="py_xs3" transition:slide>
					{#if !model}
						<!-- TODO handle this case better, maybe show a warning? -->
						<div
							class="display_flex justify_content_space_between align_items_center p_sm border_radius_xs bg_1"
						>
							<div class="display_flex gap_sm align_items_center">
								<Glyph glyph={GLYPH_INFO} />
								<span>model {item.name} not found</span>
							</div>
						</div>
					{:else}
						<div
							class="display_flex justify_content_space_between align_items_center p_sm border_radius_xs bg_1"
						>
							<div class="display_flex gap_sm align_items_center">
								<!-- TODO handle this API without the `!`, maybe change to only require the name, and derive the model -->
								<button
									type="button"
									class="icon_button plain"
									title="view model details"
									onclick={() => ollama.select(ollama.model_by_name.get(item.name)!)}
								>
									<Glyph glyph={GLYPH_INFO} />
								</button>
								<Model_Link {model} />
								{#if item.size_vram > 0}
									<small>
										VRAM: {format_bytes(item.size_vram)}
									</small>
								{/if}
							</div>
							<div class="display_flex gap_sm align_items_center">
								<!-- TODO maybe refactor with derived state -->
								{#if item.expires_at}
									{@const expires_at_date = new Date(item.expires_at)}
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
								<button
									type="button"
									class="icon_button plain"
									title="unload model from memory"
									onclick={() => ollama.unload(item.name)}
								>
									<Glyph glyph={GLYPH_DISCONNECT} />
								</button>
							</div>
						</div>
					{/if}
				</li>
			{/each}
		</ul>
	{:else}
		<p class="font_size_sm" transition:slide>no models currently loaded</p>
	{/if}
</div>
