<!-- filepath: /home/ryan/dev/zzz/src/lib/Ollama_Manager.svelte -->
<script lang="ts">
	import {slide} from 'svelte/transition';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {onMount} from 'svelte';

	import Glyph from '$lib/Glyph.svelte';
	import {
		GLYPH_CONNECT,
		GLYPH_REFRESH,
		GLYPH_DELETE,
		GLYPH_COPY,
		GLYPH_ADD,
		GLYPH_DOWNLOAD,
		GLYPH_SETTINGS,
		GLYPH_MODEL,
		GLYPH_PLACEHOLDER,
	} from '$lib/glyphs.js';
	import Error_Message from '$lib/Error_Message.svelte';
	import Ollama_Model_Detail from '$lib/Ollama_Model_Detail.svelte';
	import Ollama_Operations from '$lib/Ollama_Operations.svelte';
	import Ollama_Pull_Model from '$lib/Ollama_Pull_Model.svelte';
	import Ollama_Create_Model from '$lib/Ollama_Create_Model.svelte';
	import Ollama_Copy_Model from '$lib/Ollama_Copy_Model.svelte';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import type {Ollama} from '$lib/ollama.svelte.js';

	interface Props {
		ollama: Ollama;
	}

	const {ollama}: Props = $props();

	let show_pull_form = $state(false);
	let show_create_form = $state(false);
	let show_copy_form = $state(false);
	let show_settings = $state(false);

	// Initial load when component mounts
	onMount(() => {
		void ollama.refresh();
	});

	const handle_delete_model = async (model_name: string) => {
		console.log(`[Ollama_Manager] deleting model: ${model_name}`);
		await ollama.delete_model(model_name);
	};
</script>

<div class="display_flex flex_column gap_lg">
	<!-- Status and Connection -->
	<section class="display_flex flex_column gap_md">
		<div class="display_flex gap_sm align_items_start">
			<div
				class="flex_1 chip plain font_size_xl flex_column"
				style:display="display_flex !important"
				style:align-items="flex-start !important"
				style:font-weight="400 !important"
				class:color_b={ollama.list_status === 'success'}
				class:color_c={ollama.list_status === 'failure'}
				class:color_d={ollama.list_status === 'pending'}
				class:color_e={ollama.list_status === 'initial'}
			>
				<div class="column justify_content_center gap_xs pl_md" style:min-height="80px">
					<span>
						ollama {ollama.list_status === 'success'
							? `connected (${ollama.models_count} models)`
							: ollama.list_status === 'failure'
								? 'unavailable'
								: ollama.list_status === 'pending'
									? 'connecting'
									: 'not checked'}
						{#if ollama.list_status === 'pending'}
							<Pending_Animation inline attrs={{class: 'ml_sm'}} />
						{/if}
					</span>
					<small class="font_family_mono">{ollama.host}</small>
					{#if ollama.last_refreshed}
						<small class="text_color_dimmed">
							last refreshed: {new Date(ollama.last_refreshed).toLocaleTimeString()}
						</small>
					{/if}
				</div>
			</div>

			<div class="display_flex gap_xs">
				<button
					type="button"
					class="icon_button plain"
					title="settings"
					onclick={() => (show_settings = !show_settings)}
				>
					<Glyph glyph={GLYPH_SETTINGS} />
				</button>
			</div>
		</div>

		{#if ollama.list_error}
			<div transition:slide>
				<Error_Message><small class="font_family_mono">{ollama.list_error}</small></Error_Message>
			</div>
		{/if}

		<!-- Settings Panel -->
		{#if show_settings}
			<div class="panel p_md" transition:slide>
				<h4 class="mt_0 mb_md">
					<Glyph glyph={GLYPH_SETTINGS} /> Settings
				</h4>

				<div class="display_flex flex_column gap_md">
					<fieldset class="mb_0">
						<label for="ollama_host" class="display_block mb_xs">Host URL</label>
						<input
							id="ollama_host"
							type="text"
							class="plain flex_1"
							placeholder="{GLYPH_PLACEHOLDER} Ollama server URL"
							bind:value={ollama.host}
						/>
					</fieldset>
				</div>
			</div>
		{/if}

		<!-- Action Buttons -->
		<div class="display_flex gap_md flex_wrap">
			<button
				type="button"
				class="flex_1 justify_content_start"
				disabled={ollama.list_status === 'pending'}
				onclick={() => ollama.refresh()}
			>
				<Glyph
					glyph={ollama.list_status === 'success' ? GLYPH_REFRESH : GLYPH_CONNECT}
					size="var(--font_size_xl)"
				/>
				<span class="font_size_lg font_weight_400 ml_md">
					{#if ollama.list_status === 'pending'}
						<div class="display_inline_flex align_items_end">
							checking <div class="position_relative"><Pending_Animation /></div>
						</div>
					{:else if ollama.list_status === 'success'}
						refresh
					{:else}
						connect
					{/if}
				</span>
			</button>

			<button
				type="button"
				class="flex_1 justify_content_start color_a"
				disabled={!ollama.available}
				onclick={() => (show_pull_form = !show_pull_form)}
			>
				<Glyph glyph={GLYPH_DOWNLOAD} size="var(--font_size_xl)" />
				<span class="font_size_lg font_weight_400 ml_md">pull model</span>
			</button>

			<button
				type="button"
				class="flex_1 justify_content_start color_b"
				disabled={!ollama.available}
				onclick={() => (show_create_form = !show_create_form)}
			>
				<Glyph glyph={GLYPH_ADD} size="var(--font_size_xl)" />
				<span class="font_size_lg font_weight_400 ml_md">create model</span>
			</button>

			<button
				type="button"
				class="flex_1 justify_content_start color_d"
				disabled={!ollama.available || ollama.models_count === 0}
				onclick={() => (show_copy_form = !show_copy_form)}
			>
				<Glyph glyph={GLYPH_COPY} size="var(--font_size_xl)" />
				<span class="font_size_lg font_weight_400 ml_md">copy model</span>
			</button>
		</div>

		<!-- Operations Panel -->
		{#if ollama.pending_operations.length > 0 || ollama.completed_operations.length > 0}
			<Ollama_Operations {ollama} />
		{/if}
	</section>

	<!-- Pull Model Form -->
	{#if show_pull_form}
		<section transition:slide>
			<Ollama_Pull_Model {ollama} onclose={() => (show_pull_form = false)} />
		</section>
	{/if}

	<!-- Create Model Form -->
	{#if show_create_form}
		<section transition:slide>
			<Ollama_Create_Model {ollama} onclose={() => (show_create_form = false)} />
		</section>
	{/if}

	<!-- Copy Model Form -->
	{#if show_copy_form}
		<section transition:slide>
			<Ollama_Copy_Model {ollama} onclose={() => (show_copy_form = false)} />
		</section>
	{/if}

	<!-- Models List -->
	{#if ollama.available && ollama.models_count > 0}
		<section>
			<h3 class="mt_0 mb_md">
				<Glyph glyph={GLYPH_MODEL} /> Models ({ollama.models_count})
			</h3>

			<div class="display_flex flex_column gap_md">
				{#each ollama.models_with_details as model_detail (model_detail.model_name)}
					<div class="border border_color_2 border_radius_xs overflow_hidden">
						<!-- Model Header -->
						<div class="display_flex justify_content_space_between align_items_center p_md bg_1">
							<div class="display_flex flex_column gap_xs">
								<h4 class="mt_0 mb_0 font_family_mono">{model_detail.model_name}</h4>
								<div class="display_flex gap_md font_size_sm text_color_dimmed">
									<span
										>{model_detail.model_response
											? Math.round(model_detail.model_response.size / (1024 * 1024))
											: '?'} MB</span
									>
									<span class="font_family_mono">
										{model_detail.updated_date.toLocaleDateString()}
									</span>
								</div>
							</div>

							<div class="display_flex gap_xs">
								<Confirm_Button
									onconfirm={() => handle_delete_model(model_detail.model_name)}
									attrs={{
										class: 'icon_button plain color_c',
										title: `delete ${model_detail.model_name}`,
									}}
								>
									<Glyph glyph={GLYPH_DELETE} />

									{#snippet popover_content(popover)}
										<button
											type="button"
											class="color_c icon_button bg_c_1"
											title="confirm delete"
											onclick={() => {
												void handle_delete_model(model_detail.model_name);
												popover.hide();
											}}
										>
											<Glyph glyph={GLYPH_DELETE} />
										</button>
									{/snippet}
								</Confirm_Button>
							</div>
						</div>

						<!-- Model Details -->
						<Ollama_Model_Detail {model_detail} {ollama} />
					</div>
				{/each}
			</div>
		</section>
	{:else if ollama.available && ollama.models_count === 0}
		<section class="panel p_md" transition:slide>
			<p>
				No models found. Pull a model using the button above or install models using the Ollama CLI.
			</p>
		</section>
	{/if}
</div>
