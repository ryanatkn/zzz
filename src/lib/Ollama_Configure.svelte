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
	} from '$lib/glyphs.js';
	import Error_Message from '$lib/Error_Message.svelte';
	import Ollama_Operations from '$lib/Ollama_Operations.svelte';
	import type {Ollama} from '$lib/ollama.svelte.js';
	import {OLLAMA_URL} from '$lib/ollama_helpers.js';

	interface Props {
		ollama: Ollama;
		last_active_view: string | null;
		onback?: () => void;
	}

	const {ollama, last_active_view, onback}: Props = $props();
</script>

<div class="panel p_md">
	<div class="display_flex justify_content_space_between align_items_center mb_md">
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
	</div>

	<div class="display_flex flex_column gap_lg">
		<!-- Host Configuration -->
		<div class="display_flex flex_column gap_md">
			<fieldset>
				<label for="ollama_host" class="display_block mb_xs">Ollama host url</label>
				<input
					id="ollama_host"
					type="text"
					class="plain flex_1"
					placeholder="{GLYPH_PLACEHOLDER} {OLLAMA_URL}"
					bind:value={ollama.host}
					oninput={() => ollama.refresh()}
				/>
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
	</div>
</div>
