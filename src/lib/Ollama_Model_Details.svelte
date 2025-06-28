<script lang="ts">
	// @slop claude_sonnet_4

	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_REFRESH, GLYPH_DELETE, GLYPH_ARROW_LEFT, GLYPH_ADD} from '$lib/glyphs.js';
	import type {Model} from '$lib/model.svelte.js';
	import type {Ollama} from '$lib/ollama.svelte.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Contextmenu_Model from '$lib/Contextmenu_Model.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import {format_short_date} from '$lib/time_helpers.js';
	import {format_gigabytes} from '$lib/format_helpers.js';

	interface Props {
		model: Model;
		ollama: Ollama;
		onclose?: () => void;
		ondelete?: (model_name: string) => void;
	}

	const {model, ollama, onclose, ondelete}: Props = $props();

	const load_model_details = async () => {
		await ollama.show_model(model.name);
	};

	// TODO refactor with `Model_Detail`?
</script>

<Contextmenu_Model attrs={{class: 'display_block panel p_md'}} {model}>
	<header class="display_flex justify_content_space_between mb_md">
		<div class="display_flex flex_column gap_xs">
			<h3 class="mt_0 mb_0 font_family_mono">
				<Model_Link {model} icon />
			</h3>
			{#if model.filesize}
				<div>
					{format_gigabytes(model.filesize)}
				</div>
			{/if}
			<div class="font_family_mono">
				modified {format_short_date(model.ollama_modified_at) || '--'}
			</div>
		</div>

		{#if onclose}
			<button type="button" class="icon_button plain" onclick={onclose} title="close">
				<Glyph glyph={GLYPH_ARROW_LEFT} />
			</button>
		{/if}
	</header>

	<section class="display_flex gap_sm mb_md">
		<button
			type="button"
			class="plain"
			onclick={() => ollama.app.chats.add(undefined, true).add_tape(model)}
		>
			<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> create a new chat
		</button>

		<button
			type="button"
			class="plain"
			title="load model details"
			onclick={() => ollama.show_model(model.name)}
			disabled={model.needs_ollama_details ||
				!model.ollama_show_response_loaded ||
				model.ollama_show_response_loading}
		>
			<Glyph glyph={GLYPH_REFRESH} />&nbsp; reload details
		</button>

		{#if ondelete}
			<Confirm_Button
				onconfirm={() => ondelete(model.name)}
				position="right"
				attrs={{
					class: 'plain color_c',
					title: `delete ${model.name}`,
				}}
			>
				<Glyph glyph={GLYPH_DELETE} />&nbsp; delete model

				{#snippet popover_content(popover)}
					<button
						type="button"
						class="color_c icon_button bg_c_1"
						title="confirm delete"
						onclick={() => {
							// TODO async confirmation
							ondelete(model.name);
							popover.hide();
						}}
					>
						<Glyph glyph={GLYPH_DELETE} />
					</button>
				{/snippet}
			</Confirm_Button>
		{/if}
	</section>

	{#if model.ollama_show_response_loading}
		<section class="display_flex gap_sm align_items_center">
			<Pending_Animation />
			<span class="font_size_sm">loading model details...</span>
		</section>
	{:else if model.ollama_show_response_error}
		<section class="display_flex flex_column gap_sm">
			<div class="color_c font_size_sm">
				failed to load details: {model.ollama_show_response_error}
			</div>
			<button
				type="button"
				class="color_c icon_button plain"
				onclick={() => load_model_details()}
				title="retry loading details"
			>
				<Glyph glyph={GLYPH_REFRESH} />
			</button>
		</section>
	{:else if model.ollama_show_response}
		<section class="display_flex flex_column gap_md">
			<!-- Basic Info -->
			{#if model.ollama_show_response.details}
				<div class="display_grid gap_sm" style:grid-template-columns="auto 1fr">
					<h5 class="my_0">capabilities:</h5>
					<span class="font_family_mono">
						{model.ollama_show_response.capabilities?.join(', ') || 'none'}
					</span>

					<h5 class="my_0">parameters:</h5>
					<span class="font_family_mono">
						{model.ollama_show_response.details.parameter_size}
					</span>

					<h5 class="my_0">family:</h5>
					<span class="font_family_mono">{model.ollama_show_response.details.family}</span>

					<h5 class="my_0">quantization:</h5>
					<span class="font_family_mono">
						{model.ollama_show_response.details.quantization_level}
					</span>

					<h5 class="my_0">format:</h5>
					<span class="font_family_mono">{model.ollama_show_response.details.format}</span>

					{#if model.ollama_show_response.details.parent_model}
						<h5 class="my_0">parent:</h5>
						<span class="font_family_mono">{model.ollama_show_response.details.parent_model}</span>
					{/if}
				</div>
			{/if}

			<!-- Template -->
			{#if model.ollama_show_response.template}
				<div>
					<h5>template:</h5>
					<pre><code>{model.ollama_show_response.template}</code></pre>
				</div>
			{/if}

			<!-- Model Info -->
			{#if model.ollama_show_response.model_info && Object.keys(model.ollama_show_response.model_info).length > 0}
				<div>
					<h5>model info:</h5>
					<pre><code>{JSON.stringify(model.ollama_show_response, null, '\t')}</code></pre>
				</div>
			{/if}

			<!-- License -->
			{#if model.ollama_show_response.license}
				<div>
					<h5>license:</h5>
					<pre><code>{model.ollama_show_response.license}</code></pre>
				</div>
			{/if}

			<!-- Modelfile -->
			{#if model.ollama_show_response.modelfile}
				<div>
					<h5>modelfile:</h5>
					<pre><code>{model.ollama_show_response.modelfile}</code></pre>
				</div>
			{/if}
		</section>
	{/if}
</Contextmenu_Model>
