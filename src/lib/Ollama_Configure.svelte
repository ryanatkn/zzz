<script lang="ts">
	// @slop claude_sonnet_4

	import {slide} from 'svelte/transition';

	import Glyph from '$lib/Glyph.svelte';
	import {
		GLYPH_CONNECT,
		GLYPH_REFRESH,
		GLYPH_SETTINGS,
		GLYPH_PLACEHOLDER,
		GLYPH_ARROW_LEFT,
		GLYPH_CLEAR,
	} from '$lib/glyphs.js';
	import Error_Message from '$lib/Error_Message.svelte';
	import Ollama_Operations from '$lib/Ollama_Operations.svelte';
	import type {Ollama} from '$lib/ollama.svelte.js';
	import {OLLAMA_URL} from '$lib/ollama_helpers.js';

	interface Props {
		ollama: Ollama;
		last_active_view: string | null;
		onshowpull: () => void;
		onback?: () => void;
	}

	const {ollama, last_active_view, onshowpull, onback}: Props = $props();

	const details_cache_size = $derived(ollama.model_details_with_cached_show.length);
</script>

<div class="panel p_md">
	<header class="display_flex justify_content_space_between align_items_center mb_md">
		<h3 class="mt_0 mb_0">
			<Glyph glyph={GLYPH_SETTINGS} /> configure
		</h3>
		{#if last_active_view && onback}
			<button
				type="button"
				class="icon_button plain"
				onclick={onback}
				title="back to {last_active_view}"
			>
				<Glyph glyph={GLYPH_ARROW_LEFT} />
			</button>
		{/if}
	</header>

	<section class="width_md display_flex flex_column gap_lg">
		{#if ollama.model_count === 0}
			<p>
				Ollama is a local LLM provider. Get started by <button
					type="button"
					class="inline compact"
					onclick={onshowpull}>pulling a model</button
				>.
			</p>
		{/if}

		<!-- Host Configuration -->
		<div class="display_flex flex_column gap_md">
			<fieldset>
				<label>
					<div class="title mb_xs">Ollama host url</div>
					<input
						type="text"
						class="plain flex_1"
						placeholder="{GLYPH_PLACEHOLDER} {OLLAMA_URL}"
						bind:value={ollama.host}
						oninput={() => ollama.refresh()}
					/>
				</label>
			</fieldset>

			<div class="row gap_xs">
				<button
					type="button"
					class="justify_content_start"
					disabled={ollama.list_status === 'pending'}
					onclick={() => ollama.refresh()}
				>
					<Glyph glyph={ollama.list_status === 'success' ? GLYPH_REFRESH : GLYPH_CONNECT} />
					<span class="ml_sm">
						{#if ollama.list_status === 'pending'}
							checking...
						{:else if ollama.list_status === 'success'}
							refresh
						{:else}
							connect
						{/if}
					</span>
				</button>

				{#if ollama.host !== OLLAMA_URL}
					<div class="row gap_sm" transition:slide={{axis: 'x'}}>
						<button
							type="button"
							class="shrink_0"
							onclick={async () => {
								ollama.host = OLLAMA_URL;
								await ollama.refresh();
							}}>reset to default</button
						>
						<small class="font_family_mono">
							{OLLAMA_URL}
						</small>
					</div>
				{/if}

				{#if ollama.model_details.size > 0}
					<div class="display_flex gap_sm" transition:slide>
						<button
							type="button"
							class="plain"
							onclick={() => ollama.clear_all_model_details()}
							title="clear all cached model details"
							disabled={details_cache_size === 0}
						>
							<Glyph glyph={GLYPH_CLEAR} />&nbsp; clear details cache {#if details_cache_size}({details_cache_size}){/if}
						</button>
					</div>
				{/if}
			</div>

			{#if ollama.list_error}
				<div transition:slide>
					<Error_Message><small class="font_family_mono">{ollama.list_error}</small></Error_Message>
				</div>
			{/if}
		</div>

		<!-- Operations Panel -->
		{#if ollama.pending_operations.length > 0 || ollama.completed_operations.length > 0}
			<Ollama_Operations {ollama} />
		{/if}
	</section>
</div>
