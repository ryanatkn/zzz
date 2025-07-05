<script lang="ts">
	// @slop claude_sonnet_4

	import Glyph from '$lib/Glyph.svelte';
	import Error_Message from '$lib/Error_Message.svelte';
	import {GLYPH_ADD, GLYPH_ARROW_LEFT, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import type {Ollama} from '$lib/ollama.svelte.js';

	interface Props {
		ollama: Ollama;
		onclose: () => void;
		onshowpull: () => void;
	}

	const {ollama, onclose, onshowpull}: Props = $props();

	const handle_create = async () => {
		await ollama.create();
		onclose();
	};

	const handle_keydown = (event: KeyboardEvent) => {
		if (event.key === 'Escape') {
			onclose();
		}
	};
</script>

<div class="panel p_md">
	<header class="display_flex justify_content_space_between align_items_center mb_md">
		<h3 class="mt_0 mb_0">
			<Glyph glyph={GLYPH_ADD} /> create model
		</h3>
		<button type="button" class="icon_button plain" onclick={onclose} title="close">
			<Glyph glyph={GLYPH_ARROW_LEFT} />
		</button>
	</header>

	<section class="width_md display_flex flex_column gap_md">
		<p>
			This creates a new custom modelfile, to download a builtin model see <button
				type="button"
				class="inline compact"
				onclick={onshowpull}>pull model</button
			>.
		</p>

		<fieldset>
			<label>
				<div class="title mb_xs">new model name</div>
				<input
					type="text"
					class="plain w_100"
					placeholder="{GLYPH_PLACEHOLDER} my-custom-model"
					bind:value={ollama.create_model_name}
					onkeydown={handle_keydown}
					disabled={ollama.create_is_creating}
				/>
			</label>
		</fieldset>

		<fieldset>
			<label>
				<div class="title mb_xs">base model (optional)</div>
				{#if ollama.model_names.length > 0}
					<select
						class="plain w_100"
						bind:value={ollama.create_from_model}
						disabled={ollama.create_is_creating}
					>
						<option value="">-- select base model --</option>
						{#each ollama.model_names as model_name (model_name)}
							<option value={model_name}>{model_name}</option>
						{/each}
					</select>
				{:else}
					<input
						type="text"
						class="plain w_100"
						placeholder="{GLYPH_PLACEHOLDER} base model name"
						bind:value={ollama.create_from_model}
						onkeydown={handle_keydown}
						disabled={ollama.create_is_creating}
					/>
				{/if}
			</label>
			<p>Choose a base model to customize, or leave empty for a completely new model</p>
		</fieldset>

		<fieldset>
			<label>
				<div class="title mb_xs">system prompt (optional)</div>
				<textarea
					class="plain w_100"
					rows="4"
					placeholder="{GLYPH_PLACEHOLDER} You are a helpful assistant..."
					bind:value={ollama.create_system_prompt}
					disabled={ollama.create_is_creating}
				></textarea>
			</label>
			<p>Define the model's behavior and personality</p>
		</fieldset>

		<fieldset>
			<label>
				<div class="title mb_xs">template (optional)</div>
				<!-- Custom template using Ollama template syntax -->
				<textarea
					class="plain w_100"
					rows="3"
					placeholder="{GLYPH_PLACEHOLDER} {'{{{ .System }}}'} {'{{{ .Prompt }}}'}"
					bind:value={ollama.create_template}
					disabled={ollama.create_is_creating}
				></textarea>
			</label>
			<p>Custom prompt template using Ollama template syntax</p>
		</fieldset>

		<div class="display_flex gap_md">
			<button
				type="button"
				class="color_b"
				disabled={!ollama.create_can_create || ollama.create_is_creating}
				onclick={handle_create}
			>
				<Glyph glyph={GLYPH_ADD} />&nbsp;
				{ollama.create_is_creating ? 'creating...' : 'create model'}
			</button>
			<button type="button" class="plain" onclick={onclose} disabled={ollama.create_is_creating}
				>cancel</button
			>
		</div>

		{#if ollama.create_is_duplicate_name}
			<Error_Message>a model with this name already exists</Error_Message>
		{/if}
	</section>
</div>
