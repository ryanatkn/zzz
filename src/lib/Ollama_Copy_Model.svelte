<script lang="ts">
	// @slop claude_sonnet_4

	import Glyph from '$lib/Glyph.svelte';
	import Error_Message from '$lib/Error_Message.svelte';
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


	const parsed_source_model = $derived(source_model.trim());
	const parsed_destination_model = $derived(destination_model.trim());

	const is_duplicate_name = $derived(
		parsed_destination_model && ollama.model_by_name.has(parsed_destination_model),
	);

	const destination_model_changed = $derived(
		parsed_source_model && parsed_destination_model && !is_duplicate_name,
	);

	const handle_copy = async () => {
		if (!destination_model_changed) return;

		is_copying = true;
		try {
			await ollama.copy_model(parsed_source_model, parsed_destination_model);

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
		if (event.key === 'Enter' && !is_copying && destination_model_changed) {
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
				{#if ollama.model_names.length > 0}
					<select class="plain w_100" bind:value={source_model} disabled={is_copying}>
						<option value="">-- select source model --</option>
						{#each ollama.model_names as model_name (model_name)}
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
				disabled={!destination_model_changed || is_copying}
				onclick={handle_copy}
			>
				<Glyph glyph={GLYPH_COPY} />&nbsp;
				{is_copying ? 'copying...' : 'copy model'}
			</button>
			<button type="button" class="plain" onclick={onclose} disabled={is_copying}>cancel</button>
		</div>

		{#if is_duplicate_name}
			<Error_Message>a model with this name already exists</Error_Message>
		{/if}
	</div>
</div>
