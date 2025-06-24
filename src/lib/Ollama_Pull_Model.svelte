<script lang="ts">
	// @slop claude_sonnet_4

	import Glyph from '$lib/Glyph.svelte';
	import Error_Message from '$lib/Error_Message.svelte';
	import {GLYPH_DOWNLOAD, GLYPH_CANCEL, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import type {Ollama} from '$lib/ollama.svelte.js';

	interface Props {
		ollama: Ollama;
		onclose: () => void;
	}

	const {ollama, onclose}: Props = $props();

	let model_name = $state('');
	let insecure = $state(false);
	let is_pulling = $state(false);

	const parsed_model_name = $derived(model_name.trim());
	const is_duplicate_name = $derived(
		parsed_model_name && ollama.model_by_name.has(parsed_model_name),
	);
	const can_pull = $derived(parsed_model_name && !is_duplicate_name);

	const handle_pull = async () => {
		if (!can_pull) return;

		is_pulling = true;
		try {
			await ollama.pull_model(parsed_model_name, insecure);
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
			<Glyph glyph={GLYPH_CANCEL} />
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
				>
			</p>
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
