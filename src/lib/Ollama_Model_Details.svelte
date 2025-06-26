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

	// TODO BLOCK upstream Contextmenu_Model to have `attrs` and a prop for the element tag
</script>

<Contextmenu_Model {model}>
	<div class="panel p_md">
		<header class="display_flex justify_content_space_between mb_md">
			<div class="display_flex flex_column gap_xs">
				<h3 class="mt_0 mb_0 font_family_mono">
					<Model_Link {model} icon />
				</h3>
				<div>
					{model.filesize ? Math.round(model.filesize * 1024) : '?'} GB
				</div>
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
				onclick={() => {
					// TODO get `app` from context? or is this fine? should it be protected? generic types might make it a no-go
					const chat = ollama.app.chats.add(undefined, true);
					chat.add_tape(model);
				}}
			>
				<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> create a new chat
			</button>

			{#if model.ollama_details_loaded}
				<button
					type="button"
					class="plain"
					title="clear cache and reload details"
					onclick={() => ollama.refresh_model_details(model.name)}
				>
					<Glyph glyph={GLYPH_REFRESH} />&nbsp; reload details
				</button>
			{:else if model.needs_ollama_details}
				<div class="display_flex gap_sm align_items_center">
					<button
						type="button"
						class="plain"
						onclick={() => load_model_details()}
						title="load model details"
					>
						<Glyph glyph={GLYPH_REFRESH} />&nbsp; load details
					</button>
				</div>
			{/if}

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

		{#if model.ollama_details_loading}
			<section class="display_flex gap_sm align_items_center">
				<Pending_Animation />
				<span class="font_size_sm">loading model details...</span>
			</section>
		{:else if model.ollama_details_error}
			<section class="display_flex flex_column gap_sm">
				<div class="color_c font_size_sm">
					failed to load details: {model.ollama_details_error}
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
		{:else if model.ollama_details}
			<section class="display_flex flex_column gap_md">
				<!-- Basic Info -->
				{#if model.ollama_details.details}
					<div class="display_grid gap_sm" style:grid-template-columns="auto 1fr">
						<h5 class="my_0">family:</h5>
						<span class="font_family_mono">{model.ollama_details.details.family}</span>

						<h5 class="my_0">format:</h5>
						<span class="font_family_mono">{model.ollama_details.details.format}</span>

						<h5 class="my_0">parameters:</h5>
						<span class="font_family_mono">
							{model.ollama_details.details.parameter_size}
						</span>

						<h5 class="my_0">quantization:</h5>
						<span class="font_family_mono">
							{model.ollama_details.details.quantization_level}
						</span>

						{#if model.ollama_details.details.parent_model}
							<h5 class="my_0">parent:</h5>
							<span class="font_family_mono">{model.ollama_details.details.parent_model}</span>
						{/if}
					</div>
				{/if}

				<!-- System Prompt -->
				{#if model.ollama_details.system}
					<div>
						<h5>system prompt:</h5>
						<pre><code>{model.ollama_details.system}</code></pre>
					</div>
				{/if}

				<!-- Template -->
				{#if model.ollama_details.template}
					<div>
						<h5>template:</h5>
						<pre><code>{model.ollama_details.template}</code></pre>
					</div>
				{/if}

				<!-- Model Info -->
				{#if model.ollama_details.model_info && Object.keys(model.ollama_details.model_info).length > 0}
					<div>
						<h5>model info:</h5>
						<pre><code>{JSON.stringify(model.ollama_details, null, '\t')}</code></pre>
					</div>
				{/if}

				<!-- License -->
				{#if model.ollama_details.license}
					<div>
						<h5>license:</h5>
						<pre><code>{model.ollama_details.license}</code></pre>
					</div>
				{/if}

				<!-- Modelfile -->
				{#if model.ollama_details.modelfile}
					<div>
						<h5>modelfile:</h5>
						<pre><code>{model.ollama_details.modelfile}</code></pre>
					</div>
				{/if}
			</section>
		{/if}
	</div>
</Contextmenu_Model>
