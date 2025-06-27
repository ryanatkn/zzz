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

	const {models_not_downloaded, pending_operations} = $derived(app.ollama);

	const current_pull_operation = $derived(
		pending_operations.find(
			(op) => op.type === 'pull' && op.model === ollama.pull_parsed_model_name,
		),
	);

	const handle_pull = async () => {
		await ollama.handle_pull();
		onclose();
	};

	const handle_keydown = (event: KeyboardEvent) => {
		if (event.key === 'Enter' && !ollama.pull_is_pulling && ollama.pull_can_pull) {
			void handle_pull();
		} else if (event.key === 'Escape') {
			onclose();
		}
	};

	// TODO BLOCK show similar UI in the configure operation's list (showing progress, and req/res times, but also using actions)
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
		<p>This downloads a model so you can use it locally.</p>

		<fieldset>
			<label class="display_block mb_xs">
				<div class="title">model name</div>
				<input
					type="text"
					class="plain w_100"
					placeholder="{GLYPH_PLACEHOLDER} e.g., llama3.1, mistral, codellama"
					bind:value={ollama.pull_model_name}
					onkeydown={handle_keydown}
					disabled={ollama.pull_is_pulling}
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
							onclick={() => (ollama.pull_model_name = model.name)}
							disabled={ollama.pull_is_pulling || ollama.pull_model_name === model.name}
						>
							{model.name}
						</button>
					{/each}
				</div>
			{/if}
		</fieldset>

		<label class="display_flex gap_xs align_items_center">
			<input
				type="checkbox"
				class="compact"
				bind:checked={ollama.pull_insecure}
				disabled={ollama.pull_is_pulling}
			/>
			<span>allow insecure connections</span>
		</label>

		<div class="display_flex gap_md">
			<button
				type="button"
				class="color_a"
				disabled={!ollama.pull_can_pull || ollama.pull_is_pulling}
				onclick={handle_pull}
			>
				<Glyph glyph={GLYPH_DOWNLOAD} />&nbsp;
				{ollama.pull_is_pulling ? 'pulling...' : 'pull model'}
			</button>
			<button type="button" class="plain" onclick={onclose} disabled={ollama.pull_is_pulling}
				>cancel</button
			>
		</div>

		{#if ollama.pull_already_downloaded}
			<Error_Message>this model is already downloaded</Error_Message>
		{/if}

		{#if current_pull_operation}
			<div class="panel bg_2 p_sm">
				<div class="display_flex align_items_center gap_sm mb_xs">
					<div class="text_2">pulling {current_pull_operation.model}</div>
				</div>
				{#if current_pull_operation.progress_percent !== undefined}
					<div class="display_flex align_items_center gap_sm">
						<meter class="flex_1" value={current_pull_operation.progress_percent} min="0" max="100"
						></meter>
						<div class="text_2 size_xs">{current_pull_operation.progress_percent}%</div>
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>
