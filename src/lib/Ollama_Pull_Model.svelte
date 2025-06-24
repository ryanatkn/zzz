<script lang="ts">
	// @slop claude_sonnet_4

	import Glyph from '$lib/Glyph.svelte';
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

	const handle_pull = async () => {
		if (!model_name.trim()) return;

		is_pulling = true;
		try {
			await ollama.pull_model(model_name.trim(), insecure);
			model_name = '';
			onclose();
		} catch (error) {
			console.error('Pull failed:', error);
		} finally {
			is_pulling = false;
		}
	};

	const handle_keydown = (event: KeyboardEvent) => {
		if (event.key === 'Enter' && !is_pulling && model_name.trim()) {
			void handle_pull();
		} else if (event.key === 'Escape') {
			onclose();
		}
	};
</script>

<div class="panel p_md">
	<div class="display_flex justify_content_space_between align_items_center mb_md">
		<h3 class="mt_0 mb_0">
			<Glyph glyph={GLYPH_DOWNLOAD} /> pull model
		</h3>
		<button type="button" class="icon_button plain" onclick={onclose} title="close">
			<Glyph glyph={GLYPH_CANCEL} />
		</button>
	</div>

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
				disabled={!model_name.trim() || is_pulling}
				onclick={handle_pull}
			>
				<Glyph glyph={GLYPH_DOWNLOAD} />&nbsp;
				{is_pulling ? 'pulling...' : 'pull model'}
			</button>
			<button type="button" class="plain" onclick={onclose} disabled={is_pulling}>cancel</button>
		</div>
	</div>
</div>
