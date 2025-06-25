<script lang="ts">
	// @slop claude_sonnet_4

	import Glyph from '$lib/Glyph.svelte';
	import Error_Message from '$lib/Error_Message.svelte';
	import {GLYPH_DOWNLOAD, GLYPH_ARROW_LEFT, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import type {Ollama} from '$lib/ollama.svelte.js';
	import {frontend_context} from '$lib/frontend.svelte.js';

	interface Props {
		ollama: Ollama;
		onclose: () => void;
	}

	const {ollama, onclose}: Props = $props();

	const app = frontend_context.get();

	let model_name = $state('');
	let insecure = $state(false);
	let is_pulling = $state(false);

	const parsed_model_name = $derived(model_name.trim());
	const is_duplicate_name = $derived(
		parsed_model_name && ollama.model_by_name.has(parsed_model_name),
	);
	const can_pull = $derived(parsed_model_name && !is_duplicate_name);

	const models_not_downloaded = $derived(app.ollama.models_not_downloaded);

	const handle_pull = async () => {
		if (!can_pull) return;

		is_pulling = true;
		try {
			await ollama.pull_model(parsed_model_name, {insecure});
			model_name = '';
			onclose();
		} catch (error) {
			console.error('Pull failed:', error);
		} finally {
			is_pulling = false;
		}
	};

	const handle_keydown = (event: KeyboardEvent) => {
		if (event.key === 'Enter' && !is_pulling && can_pull) {
			void handle_pull();
		} else if (event.key === 'Escape') {
			onclose();
		}
	};
</script>

<div class="panel p_md">
	<header class="display_flex justify_content_space_between align_items_center mb_md">
		<h3 class="mt_0 mb_0">
			<Glyph glyph={GLYPH_DOWNLOAD} /> pull model
		</h3>
		<button type="button" class="icon_button plain" onclick={onclose} title="close">
			<Glyph glyph={GLYPH_ARROW_LEFT} />
		</button>
	</header>

	<div class="width_md display_flex flex_column gap_md">
		<fieldset>
			<label class="display_block mb_xs">
				<div class="title">model name</div>
				<input
					type="text"
					class="plain w_100"
					placeholder="{GLYPH_PLACEHOLDER} e.g., llama3.1, mistral, codellama"
					bind:value={model_name}
					onkeydown={handle_keydown}
					disabled={is_pulling}
				/>
			</label>
			<p>
				Enter a model name from the <a
					href="https://ollama.com/library"
					target="_blank"
					rel="noopener noreferrer">Ollama library</a
				>.
			</p>
			{#if models_not_downloaded.length > 0}
				<p>Available models not yet downloaded:</p>
				<div class="display_flex flex_wrap gap_xs">
					{#each models_not_downloaded as model (model.id)}
						<button
							type="button"
							class="compact"
							onclick={() => (model_name = model.name)}
							disabled={is_pulling || model_name === model.name}
						>
							{model.name}
						</button>
					{/each}
				</div>
			{/if}
		</fieldset>

		<label class="display_flex gap_xs align_items_center">
			<input type="checkbox" class="compact" bind:checked={insecure} disabled={is_pulling} />
			<span>allow insecure connections</span>
		</label>

		<div class="display_flex gap_md">
			<button
				type="button"
				class="color_a"
				disabled={!can_pull || is_pulling}
				onclick={handle_pull}
			>
				<Glyph glyph={GLYPH_DOWNLOAD} />&nbsp;
				{is_pulling ? 'pulling...' : 'pull model'}
			</button>
			<button type="button" class="plain" onclick={onclose} disabled={is_pulling}>cancel</button>
		</div>

		{#if is_duplicate_name}
			<Error_Message>a model with this name already exists</Error_Message>
		{/if}
	</div>
</div>
