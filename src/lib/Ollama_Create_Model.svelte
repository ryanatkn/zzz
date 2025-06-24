<script lang="ts">
	// @slop claude_sonnet_4

	import Glyph from '$lib/Glyph.svelte';
	import Error_Message from '$lib/Error_Message.svelte';
	import {GLYPH_ADD, GLYPH_CANCEL, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import type {Ollama} from '$lib/ollama.svelte.js';

	interface Props {
		ollama: Ollama;
		onclose: () => void;
		onshowpull: () => void;
	}

	const {ollama, onclose, onshowpull}: Props = $props();

	let model_name = $state('');
	let from_model = $state('');
	let system_prompt = $state('');
	let template = $state('');
	let is_creating = $state(false);

	const parsed_model_name = $derived(model_name.trim());
	const is_duplicate_name = $derived(
		parsed_model_name && ollama.model_by_name.has(parsed_model_name),
	);
	const can_create = $derived(parsed_model_name && !is_duplicate_name);

	// TODO BLOCK is this correct? ` or leave empty for a completely new model`

	const handle_create = async () => {
		if (!can_create) return;

		is_creating = true;
		try {
			// Build a simple Modelfile if we have custom prompts
			let modelfile = '';
			if (from_model) {
				modelfile += `FROM ${from_model}\n`;
			}
			if (system_prompt.trim()) {
				modelfile += `SYSTEM ${system_prompt.trim()}\n`;
			}
			if (template.trim()) {
				modelfile += `TEMPLATE ${template.trim()}\n`;
			}

			await ollama.create_model(
				parsed_model_name,
				from_model.trim() || undefined,
				modelfile || undefined,
			);

			// Reset form
			model_name = '';
			from_model = '';
			system_prompt = '';
			template = '';
			onclose();
		} catch (error) {
			console.error('Create failed:', error);
		} finally {
			is_creating = false;
		}
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
			<Glyph glyph={GLYPH_CANCEL} />
		</button>
	</header>
	<p>
		This creates a new custom modelfile, to download a builtin model see <button
			type="button"
			class="inline compact"
			onclick={onshowpull}>pull model</button
		>.
	</p>

	<div class="width_md display_flex flex_column gap_md">
		<fieldset>
			<label>
				<div class="title mb_xs">new model name</div>
				<input
					type="text"
					class="plain w_100"
					placeholder="{GLYPH_PLACEHOLDER} my-custom-model"
					bind:value={model_name}
					onkeydown={handle_keydown}
					disabled={is_creating}
				/>
			</label>
		</fieldset>

		<fieldset>
			<label>
				<div class="title mb_xs">base model (optional)</div>
				{#if ollama.model_names.length > 0}
					<select class="plain w_100" bind:value={from_model} disabled={is_creating}>
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
						bind:value={from_model}
						onkeydown={handle_keydown}
						disabled={is_creating}
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
					bind:value={system_prompt}
					disabled={is_creating}
				></textarea>
			</label>
			<p>Define the model's behavior and personality</p>
		</fieldset>

		<fieldset>
			<label>
				<div class="title mb_xs">template (optional)</div>
				<!-- TODO fix this placeholder -->
				<textarea
					class="plain w_100"
					rows="3"
					placeholder="{GLYPH_PLACEHOLDER} {'{{{ .System }}}'} {'{{{ .Prompt }}}'}"
					bind:value={template}
					disabled={is_creating}
				></textarea>
			</label>
			<p>Custom prompt template using Ollama template syntax</p>
		</fieldset>

		<div class="display_flex gap_md">
			<button
				type="button"
				class="color_b"
				disabled={!can_create || is_creating}
				onclick={handle_create}
			>
				<Glyph glyph={GLYPH_ADD} />&nbsp;
				{is_creating ? 'creating...' : 'create model'}
			</button>
			<button type="button" class="plain" onclick={onclose} disabled={is_creating}>cancel</button>
		</div>

		{#if is_duplicate_name}
			<Error_Message>a model with this name already exists</Error_Message>
		{/if}
	</div>
</div>
