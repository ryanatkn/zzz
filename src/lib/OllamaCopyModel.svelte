<script lang="ts">
	// @slop claude_sonnet_4

	import Glyph from '$lib/Glyph.svelte';
	import ErrorMessage from '$lib/ErrorMessage.svelte';
	import {GLYPH_COPY, GLYPH_ARROW_LEFT, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import type {Ollama} from '$lib/ollama.svelte.js';

	const {
		ollama,
		onclose,
	}: {
		ollama: Ollama;
		onclose: () => void;
	} = $props();

	const handle_copy = async () => {
		await ollama.copy();
		onclose();
	};

	const handle_keydown = (event: KeyboardEvent) => {
		if (event.key === 'Enter' && !ollama.copy_is_copying && ollama.copy_destination_model_changed) {
			void handle_copy();
		} else if (event.key === 'Escape') {
			onclose();
		}
	};
</script>

<div class="panel p_md">
	<header class="display_flex justify_content_space_between align_items_center mb_md">
		<h3 class="mt_0 mb_0">
			<Glyph glyph={GLYPH_COPY} /> copy model
		</h3>
		<button type="button" class="icon_button plain" onclick={onclose} title="close">
			<Glyph glyph={GLYPH_ARROW_LEFT} />
		</button>
	</header>

	<section class="width_upto_md display_flex flex_direction_column gap_md">
		<p>Create a copy of the source model with a new name.</p>

		<fieldset>
			<label>
				<div class="title mb_xs">source model</div>
				{#if ollama.model_names.length > 0}
					<select
						class="plain width_100"
						bind:value={ollama.copy_source_model}
						disabled={ollama.copy_is_copying}
					>
						<option value="">-- select source model --</option>
						{#each ollama.model_names as model_name (model_name)}
							<option value={model_name}>{model_name}</option>
						{/each}
					</select>
				{:else}
					<input
						type="text"
						class="plain width_100"
						placeholder="{GLYPH_PLACEHOLDER} source model name"
						bind:value={ollama.copy_source_model}
						onkeydown={handle_keydown}
						disabled={ollama.copy_is_copying}
					/>
				{/if}
			</label>
		</fieldset>

		<fieldset>
			<label>
				<div class="title mb_xs">destination model name</div>
				<input
					type="text"
					class="plain width_100"
					placeholder="{GLYPH_PLACEHOLDER} new model name"
					bind:value={ollama.copy_destination_model}
					onkeydown={handle_keydown}
					disabled={ollama.copy_is_copying}
				/>
			</label>
		</fieldset>

		<div class="display_flex gap_md">
			<button
				type="button"
				class="color_d"
				disabled={!ollama.copy_destination_model_changed || ollama.copy_is_copying}
				onclick={handle_copy}
			>
				<Glyph glyph={GLYPH_COPY} />&nbsp;
				{ollama.copy_is_copying ? 'copying...' : 'copy model'}
			</button>
			<button type="button" class="plain" onclick={onclose} disabled={ollama.copy_is_copying}
				>cancel</button
			>
		</div>

		{#if ollama.copy_is_duplicate_name}
			<ErrorMessage>a model with this name already exists</ErrorMessage>
		{/if}
	</section>
</div>
