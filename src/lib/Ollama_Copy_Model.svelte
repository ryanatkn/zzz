<script lang="ts">
	// @slop claude_sonnet_4

	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_COPY, GLYPH_CANCEL, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import type {Ollama} from '$lib/ollama.svelte.js';

	interface Props {
		ollama: Ollama;
		onclose: () => void;
	}

	const {ollama, onclose}: Props = $props();

	let source_model = $state('');
	let destination_model = $state('');
	let is_copying = $state(false);

	const available_models = $derived(ollama.list_response?.models.map((m) => m.name) || []);

	const handle_copy = async () => {
		if (!source_model.trim() || !destination_model.trim()) return;

		is_copying = true;
		try {
			await ollama.copy_model(source_model.trim(), destination_model.trim());

			// Reset form
			source_model = '';
			destination_model = '';
			onclose();
		} catch (error) {
			console.error('Copy failed:', error);
		} finally {
			is_copying = false;
		}
	};

	const handle_keydown = (event: KeyboardEvent) => {
		if (event.key === 'Enter' && !is_copying && source_model.trim() && destination_model.trim()) {
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
			<Glyph glyph={GLYPH_CANCEL} />
		</button>
	</header>

	<div class="width_md display_flex flex_column gap_md">
		<fieldset>
			<label>
				<div class="title mb_xs">source model</div>
				{#if available_models.length > 0}
					<select class="plain w_100" bind:value={source_model} disabled={is_copying}>
						<option value="">-- select source model --</option>
						{#each available_models as model_name (model_name)}
							<option value={model_name}>{model_name}</option>
						{/each}
					</select>
				{:else}
					<input
						type="text"
						class="plain w_100"
						placeholder="{GLYPH_PLACEHOLDER} source model name"
						bind:value={source_model}
						onkeydown={handle_keydown}
						disabled={is_copying}
					/>
				{/if}
			</label>
		</fieldset>

		<fieldset>
			<label>
				<div class="title mb_xs">destination model name</div>
				<input
					type="text"
					class="plain w_100"
					placeholder="{GLYPH_PLACEHOLDER} new model name"
					bind:value={destination_model}
					onkeydown={handle_keydown}
					disabled={is_copying}
				/>
			</label>
			<p>Create a copy of the source model with a new name</p>
		</fieldset>

		<div class="display_flex gap_md">
			<button
				type="button"
				class="color_d"
				disabled={!source_model.trim() || !destination_model.trim() || is_copying}
				onclick={handle_copy}
			>
				<Glyph glyph={GLYPH_COPY} />&nbsp;
				{is_copying ? 'copying...' : 'copy model'}
			</button>
			<button type="button" class="plain" onclick={onclose} disabled={is_copying}>cancel</button>
		</div>
	</div>
</div>
