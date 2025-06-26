<script lang="ts">
	import {base} from '$app/paths';
	import {page} from '$app/state';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {onMount} from 'svelte';

	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import type {Model} from '$lib/model.svelte.js';
	import {
		GLYPH_MODEL,
		GLYPH_REFRESH,
		GLYPH_ERROR,
		GLYPH_CHECKMARK,
		GLYPH_ADD,
		GLYPH_DOWNLOAD,
	} from '$lib/glyphs.js';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import Glyph from '$lib/Glyph.svelte';
	import {format_short_date} from '$lib/time_helpers.js';
	import Contextmenu_Model from '$lib/Contextmenu_Model.svelte';

	interface Props {
		model: Model;
		attrs?: SvelteHTMLElements['span'] | undefined;
	}

	const {model, attrs}: Props = $props();

	const app = frontend_context.get();

	// Initial load when component mounts
	onMount(async () => {
		if (model.needs_ollama_details) {
			await app.ollama.show_model(model.name);
		}
	});

	const at_detail_page = $derived(page.url.pathname === `${base}/models/${model.name}`);
	const provider = $derived(app.providers.find_by_name(model.provider_name));

	const load_ollama_details = async () => {
		if (model.needs_ollama_details) {
			await app.ollama.show_model(model.name);
		}
	};

	const reload_ollama_details = async () => {
		if (model.provider_name === 'ollama') {
			await app.ollama.refresh_model_details(model.name);
		}
	};

	// Format file size nicely
	const format_file_size = (gb: number): string => {
		if (gb < 1) {
			return `${Math.round(gb * 1024)} MB`;
		}
		return `${gb.toFixed(1)} GB`;
	};
</script>

<!-- TODO hacky, I guess adding clsx as a dep like Svelte makes sense? -->
<!-- eslint-disable-next-line @typescript-eslint/no-base-to-string -->
<Contextmenu_Model
	tag="div"
	attrs={{...attrs, class: 'panel p_lg ' + (attrs?.class || '')}}
	{model}
>
	<section class="row">
		<div class="glyph_container">
			<Glyph glyph={GLYPH_MODEL} size="var(--icon_size_xl)" />
		</div>
		<div class="pl_xl">
			{#if at_detail_page}
				<h1 class="mb_md">
					{model.name}
				</h1>
			{:else}
				<h2>
					<Model_Link {model} />
				</h2>
			{/if}
			<div class="display_flex font_family_mono ml_sm mb_md font_size_lg">
				<Provider_Link {provider} attrs={{class: 'row gap_sm'}} icon="svg" />
			</div>
			{#if model.downloaded !== undefined}
				<div class="column mb_lg">
					{#if model.downloaded}
						<small>
							{GLYPH_CHECKMARK} downloaded
						</small>
					{/if}
				</div>
			{/if}
			{#if model.tags.length}
				<ul class="unstyled display_flex gap_xs">
					{#each model.tags as tag (tag)}
						<small class="chip font_weight_400">{tag}</small>
					{/each}
				</ul>
			{/if}
		</div>
	</section>

	<section class="display_flex gap_xs">
		{#if model.provider_name === 'ollama' && !model.downloaded}
			<button type="button" class="color_b" onclick={() => model.navigate_to_download()}>
				<Glyph glyph={GLYPH_DOWNLOAD} attrs={{class: 'mr_xs2'}} /> download model
			</button>
		{:else}
			<button
				type="button"
				class="color_d"
				onclick={() => {
					const chat = app.chats.add(undefined, true);
					chat.add_tape(model);
				}}
			>
				<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> create a new chat
			</button>
		{/if}
	</section>

	{#if model.provider_name !== 'ollama'}
		<aside class="mt_xl3">
			⚠️ This information is incomplete and may be incorrect or outdated.
		</aside>
	{/if}

	<section>
		<h2>Specs</h2>
		<div>
			{#if model.context_window}
				<div>
					<strong>context window:</strong>
					{model.context_window.toLocaleString()} tokens
				</div>
			{/if}
			{#if model.output_token_limit}
				<div>
					<strong>output limit:</strong>
					{model.output_token_limit.toLocaleString()} tokens
				</div>
			{/if}
			{#if model.parameter_count}
				<div>
					<strong>parameters:</strong>
					{model.parameter_count.toLocaleString()}B
				</div>
			{/if}
			{#if model.filesize}
				<div>
					<strong>file size:</strong>
					{format_file_size(model.filesize)}
				</div>
			{/if}
			{#if model.architecture}
				<div>
					<strong>architecture:</strong>
					{model.architecture}
				</div>
			{/if}
			{#if model.embedding_length}
				<div>
					<strong>embedding length:</strong>
					{model.embedding_length.toLocaleString()}
				</div>
			{/if}
			{#if model.training_cutoff}
				<div>
					<strong>training cutoff:</strong>
					{model.training_cutoff}
				</div>
			{/if}

			{#if model.ollama_list_data?.details}
				{#if model.ollama_list_data.details.format}
					<div>
						<strong>format:</strong>
						{model.ollama_list_data.details.format}
					</div>
				{/if}
				{#if model.ollama_list_data.details.quantization_level}
					<div>
						<strong>quantization:</strong>
						{model.ollama_list_data.details.quantization_level}
					</div>
				{/if}
				{#if model.ollama_list_data.details.families.length}
					<div>
						<strong>families:</strong>
						{model.ollama_list_data.details.families.join(', ')}
					</div>
				{/if}
			{/if}
		</div>

		{#if model.cost_input || model.cost_output}
			<section>
				<h3>pricing</h3>
				{#if model.cost_input}
					<div><strong>input:</strong> ${model.cost_input.toFixed(2)} / 1M tokens</div>
				{/if}
				{#if model.cost_output}
					<div><strong>output:</strong> ${model.cost_output.toFixed(2)} / 1M tokens</div>
				{/if}
			</section>
		{/if}

		{#if model.provider_name === 'ollama'}
			<section>
				<div class="display_flex justify_content_space_between align_items_center mb_md">
					<h3>Ollama details</h3>

					<div class="display_flex gap_sm">
						{#if model.ollama_details_loaded}
							<button
								type="button"
								class="plain icon_button"
								onclick={reload_ollama_details}
								title="reload details"
							>
								<Glyph glyph={GLYPH_REFRESH} />
							</button>
						{:else if model.needs_ollama_details}
							<button
								type="button"
								class="compact"
								onclick={load_ollama_details}
								disabled={model.ollama_details_loading}
							>
								{#if model.ollama_details_loading}
									<Pending_Animation inline /> loading...
								{:else}
									<Glyph glyph={GLYPH_REFRESH} /> load details
								{/if}
							</button>
						{/if}
					</div>
				</div>

				{#if model.ollama_modified_at}
					<div>
						<h4>modified</h4>
						{format_short_date(model.ollama_modified_at)}
					</div>
				{/if}

				{#if model.ollama_details_error}
					<div class="panel p_sm color_c mb_md">
						<Glyph glyph={GLYPH_ERROR} /> failed to load details: {model.ollama_details_error}
					</div>
				{/if}

				{#if model.ollama_list_data}
					<div class="subsection">
						<h4>model info</h4>
						<div>
							<strong>digest:</strong>
							<code class="font_size_sm">{model.ollama_list_data.digest}</code>
						</div>
						{#if model.ollama_list_data.size}
							<div>
								<strong>size:</strong>
								{(model.ollama_list_data.size / (1024 * 1024 * 1024)).toFixed(2)} GB
							</div>
						{/if}
						{#if model.ollama_list_data.details?.parent_model}
							<div>
								<strong>parent:</strong>
								{model.ollama_list_data.details.parent_model}
							</div>
						{/if}
					</div>
				{/if}

				{#if model.ollama_details}
					{#if model.ollama_details.system}
						<h4>system prompt</h4>
						<pre class="code_block"><code>{model.ollama_details.system}</code></pre>
					{/if}

					{#if model.ollama_details.template}
						<h4>template</h4>
						<pre class="code_block"><code>{model.ollama_details.template}</code></pre>
					{/if}

					{#if model.ollama_details.model_info && Object.keys(model.ollama_details.model_info).length > 0}
						<h4>model info</h4>
						<pre class="code_block"><code
								>{JSON.stringify(model.ollama_details.model_info, null, 2)}</code
							></pre>
					{/if}

					{#if model.ollama_details.license}
						<h4>license</h4>
						<pre class="code_block"><code>{model.ollama_details.license}</code></pre>
					{/if}

					{#if model.ollama_details.modelfile}
						<details>
							<summary><h4 class="display_inline">modelfile</h4></summary>
							<pre class="code_block mt_sm"><code>{model.ollama_details.modelfile}</code></pre>
						</details>
					{/if}
				{/if}
			</section>
		{/if}
	</section>
</Contextmenu_Model>

<style>
	.glyph_container {
		display: flex;
		align-items: center;
		justify-content: center;
		min-width: var(--icon_size_xl);
		line-height: 1;
	}
</style>
