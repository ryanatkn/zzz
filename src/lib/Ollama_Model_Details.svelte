<script lang="ts">
	// @slop claude_sonnet_4

	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import Details from '@ryanatkn/fuz/Details.svelte';
	import type {Snippet} from 'svelte';

	import Glyph from '$lib/Glyph.svelte';
	import {
		GLYPH_REFRESH,
		GLYPH_DELETE,
		GLYPH_ARROW_LEFT,
		GLYPH_ADD,
		GLYPH_DOWNLOAD,
	} from '$lib/glyphs.js';
	import type {Model} from '$lib/model.svelte.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Contextmenu_Model from '$lib/Contextmenu_Model.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import {format_short_date} from '$lib/time_helpers.js';
	import {format_gigabytes} from '$lib/format_helpers.js';

	interface Props {
		model: Model;
		// TODO maybe dont include these args?
		onshow: (model: Model) => void;
		onclose?: (model: Model) => void;
		ondelete?: (model: Model) => void;
		header?: Snippet;
	}

	const {model, onshow, onclose, ondelete, header}: Props = $props();

	// TODO refactor with `Model_Detail`?
</script>

<Contextmenu_Model {model}>
	{#if header}
		{@render header()}
	{:else}
		<header class="display_flex justify_content_space_between mb_md">
			<div class="display_flex flex_column gap_xs">
				<h3 class="mt_0 mb_0 font_family_mono">
					<Model_Link {model} icon />
				</h3>
			</div>
			{#if onclose}
				<button
					type="button"
					class="icon_button plain"
					onclick={() => onclose(model)}
					title="close"
				>
					<Glyph glyph={GLYPH_ARROW_LEFT} />
				</button>
			{/if}
		</header>
	{/if}

	<section class="display_flex gap_sm mb_xl3">
		{#if model.downloaded}
			<button
				type="button"
				class="plain"
				onclick={() => model.app.chats.add(undefined, true).add_tape(model)}
			>
				<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> create a new chat
			</button>

			<button
				type="button"
				class="plain"
				title="load model details"
				onclick={() => onshow(model)}
				disabled={model.needs_ollama_details ||
					!model.ollama_show_response_loaded ||
					model.ollama_show_response_loading}
			>
				<Glyph glyph={GLYPH_REFRESH} />&nbsp; reload details
			</button>

			{#if ondelete}
				<Confirm_Button
					onconfirm={() => ondelete(model)}
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
								ondelete(model);
								popover.hide();
							}}
						>
							<Glyph glyph={GLYPH_DELETE} />
						</button>
					{/snippet}
				</Confirm_Button>
			{/if}
		{:else}
			<button
				type="button"
				class="color_a"
				onclick={() => model.navigate_to_download()}
				title="download this model"
			>
				<Glyph glyph={GLYPH_DOWNLOAD} attrs={{class: 'mr_xs2'}} /> download model
			</button>
		{/if}
	</section>

	{#if !model.downloaded}
		<section class="panel p_md">
			<p class="color_d font_size_sm mt_0 mb_0">not downloaded</p>
		</section>
	{:else if model.ollama_show_response_loading}
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
				onclick={() => onshow(model)}
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

					{#if model.filesize}
						<h5 class="my_0">filesize:</h5>
						<span class="font_family_mono">{format_gigabytes(model.filesize)}</span>
					{/if}

					{#if model.ollama_modified_at}
						<h5 class="my_0">modified:</h5>
						<span class="font_family_mono">{format_short_date(model.ollama_modified_at)}</span>
					{/if}

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
				<Details attrs={{class: 'mt_xl3'}}>
					{#snippet summary()}<h5 class="display_inline">modelfile:</h5>{/snippet}
					<pre><code>{model.ollama_show_response.modelfile}</code></pre>
				</Details>
			{/if}
		</section>
	{/if}
</Contextmenu_Model>
