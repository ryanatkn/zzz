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
	import type {Ollama, Ollama_Model_Detail as ModelDetailType} from '$lib/ollama.svelte.js';
	import {OLLAMA_URL} from './ollama_helpers.js';

	interface Props {
		ollama: Ollama;
	}

	const {ollama}: Props = $props();

	// TODO think about snapshotting/loading this and ollama.svelte.ts data

	let selected_view: 'configure' | 'model' | 'pull' | 'create' | 'copy' = $state('configure');
	let selected_model_detail: ModelDetailType | null = $state(null);

	// Initial load when component mounts
	onMount(() => {
		void ollama.refresh();
	});

	const handle_delete_model = async (model_name: string) => {
		console.log(`[Ollama_Manager] deleting model: ${model_name}`);
		await ollama.delete_model(model_name);
		// Clear selection if the deleted model was selected
		if (selected_model_detail?.model_name === model_name) {
			selected_model_detail = null;
			selected_view = 'configure';
		}
	};

	const handle_select_model = async (model_detail: ModelDetailType) => {
		selected_model_detail = model_detail;
		selected_view = 'model';
		// Auto-load details if not already loaded
		if (model_detail.show_status === 'initial') {
			await ollama.show_model(model_detail.model_name);
		}
	};

	const handle_show_pull = () => {
		selected_view = 'pull';
		selected_model_detail = null;
	};

	const handle_show_create = () => {
		selected_view = 'create';
		selected_model_detail = null;
	};

	const handle_show_copy = () => {
		selected_view = 'copy';
		selected_model_detail = null;
	};

	const handle_close_form = () => {
		selected_view = 'configure';
		selected_model_detail = null;
	};
</script>

<div class="display_flex h_100">
	<!-- Sidebar -->
	<div class="h_100 overflow_hidden width_sm min_width_sm">
		<div class="h_100 overflow_auto scrollbar_width_thin p_md">
			<!-- Status and Connection -->
			<section class="display_flex flex_column gap_md mb_lg">
				<div class="display_flex gap_sm align_items_start">
					<div
						class="flex_1 chip plain display_flex justify_content_start font_weight_400"
						class:color_b={ollama.list_status === 'success'}
						class:color_c={ollama.list_status === 'failure'}
						class:color_d={ollama.list_status === 'pending'}
						class:color_e={ollama.list_status === 'initial'}
					>
						<div class="column justify_content_center gap_xs p_md">
							<span class="font_size_lg">
								ollama {ollama.list_status === 'success'
									? `connected`
									: ollama.list_status === 'failure'
										? 'unavailable'
										: ollama.list_status === 'pending'
											? 'connecting'
											: 'not checked'}
								{#if ollama.list_status === 'pending'}
									<Pending_Animation inline attrs={{class: 'ml_sm'}} />
								{/if}
							</span>
							<div class="font_family_mono font_size_sm">{ollama.host}</div>
							{#if ollama.last_refreshed_from_now}
								<div class="font_size_sm">
									refreshed {ollama.last_refreshed_from_now}
								</div>
							{/if}
						</div>
					</div>
				</div>

				{#if ollama.list_error}
					<div transition:slide>
						<Error_Message
							><small class="font_family_mono">{ollama.list_error}</small></Error_Message
						>
					</div>
				{/if}

				<div class="row justify_content_space_between gap_xs">
					<button
						type="button"
						class="justify_content_start"
						disabled={ollama.list_status === 'pending'}
						onclick={() => ollama.refresh()}
					>
						<Glyph glyph={ollama.list_status === 'success' ? GLYPH_REFRESH : GLYPH_CONNECT} />
						<span class="ml_sm">
							{#if ollama.list_status === 'pending'}
								checking...
							{:else if ollama.list_status === 'success'}
								refresh
							{:else}
								connect
							{/if}
						</span>
					</button>
				</div>

				<!-- View Selection -->
				<div class="flex_column gap_sm">
					<button
						type="button"
						class="w_100 justify_content_start border_radius_0"
						class:selected={selected_view === 'configure'}
						onclick={() => {
							selected_view = 'configure';
							selected_model_detail = null;
						}}
					>
						<Glyph glyph={GLYPH_SETTINGS} />
						<span class="ml_sm">configure</span>
					</button>
				</div>

				<!-- Action Buttons -->
				<div class="flex_column gap_sm">
					<button
						type="button"
						class="w_100 justify_content_start color_a border_radius_0"
						class:selected={selected_view === 'pull'}
						disabled={!ollama.available}
						onclick={handle_show_pull}
					>
						<Glyph glyph={GLYPH_DOWNLOAD} />
						<span class="ml_sm">pull model</span>
					</button>

					<button
						type="button"
						class="w_100 justify_content_start border_radius_0"
						class:selected={selected_view === 'create'}
						disabled={!ollama.available}
						onclick={handle_show_create}
					>
						<Glyph glyph={GLYPH_ADD} />
						<span class="ml_sm">create model</span>
					</button>

					<button
						type="button"
						class="w_100 justify_content_start border_radius_0"
						class:selected={selected_view === 'copy'}
						disabled={!ollama.available || ollama.models_count === 0}
						onclick={handle_show_copy}
					>
						<Glyph glyph={GLYPH_COPY} />
						<span class="ml_sm">copy model</span>
					</button>
				</div>
			</section>

			<!-- Models List -->
			{#if ollama.available && ollama.models_count > 0}
				<section>
					<h4 class="mt_0 mb_md">
						<Glyph glyph={GLYPH_MODEL} /> models ({ollama.models_count})
					</h4>

					<div class="display_flex flex_column gap_xs">
						{#each ollama.models_with_details as model_detail (model_detail.model_name)}
							<button
								type="button"
								class="menu_item text_align_start p_sm border_radius_xs"
								class:selected={selected_view === 'model' &&
									selected_model_detail?.model_name === model_detail.model_name}
								onclick={() => handle_select_model(model_detail)}
							>
								<div class="display_flex flex_column gap_xs">
									<div class="font_weight_600 font_family_mono ellipsis">
										{model_detail.model_name}
									</div>
									<div class="display_flex gap_md font_size_sm">
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
							</button>
						{/each}
					</div>
				</section>
			{:else if ollama.available && ollama.models_count === 0}
				<section class="panel p_md" transition:slide>
					<p>
						no models found. pull a model using the button above or install models using the ollama
						CLI.
					</p>
				</section>
			{/if}
		</div>
	</div>

	<!-- Main Content -->
	<div class="flex_1 h_100">
		{#if selected_view === 'configure'}
			<div class="h_100 overflow_auto p_md">
				<div class="panel p_md">
					<h3 class="mt_0 mb_md">
						<Glyph glyph={GLYPH_SETTINGS} /> configure
					</h3>

					<div class="display_flex flex_column gap_lg">
						<!-- Host Configuration -->
						<div class="display_flex flex_column gap_md">
							<fieldset class="mb_0">
								<label for="ollama_host" class="display_block mb_xs">ollama host url</label>
								<input
									id="ollama_host"
									type="text"
									class="plain flex_1"
									placeholder="{GLYPH_PLACEHOLDER} {OLLAMA_URL}"
									bind:value={ollama.host}
									oninput={() => ollama.refresh()}
								/>
							</fieldset>
							{#if ollama.host !== OLLAMA_URL}
								<div class="row gap_sm" transition:slide>
									<button
										type="button"
										onclick={async () => {
											ollama.host = OLLAMA_URL;
											await ollama.refresh();
										}}>reset to default</button
									>
									<small class="font_family_mono">
										{OLLAMA_URL}
									</small>
								</div>
							{/if}
						</div>

						<!-- Operations Panel -->
						{#if ollama.pending_operations.length > 0 || ollama.completed_operations.length > 0}
							<Ollama_Operations {ollama} />
						{/if}
					</div>
				</div>
			</div>
		{:else if selected_view === 'model' && selected_model_detail}
			<div class="h_100 overflow_auto p_md">
				<div class="panel p_md">
					<!-- Model Header -->
					<div class="display_flex justify_content_space_between align_items_center mb_md">
						<div class="display_flex flex_column gap_xs">
							<h3 class="mt_0 mb_0 font_family_mono">{selected_model_detail.model_name}</h3>
							<div class="display_flex gap_md font_size_sm">
								<span
									>{selected_model_detail.model_response
										? Math.round(selected_model_detail.model_response.size / (1024 * 1024))
										: '?'} MB</span
								>
								<span class="font_family_mono">
									{selected_model_detail.updated_date.toLocaleDateString()}
								</span>
							</div>
						</div>

						<div class="display_flex gap_xs">
							<Confirm_Button
								onconfirm={() =>
									selected_model_detail && handle_delete_model(selected_model_detail.model_name)}
								attrs={{
									class: 'icon_button plain color_c',
									title: `delete ${selected_model_detail.model_name}`,
								}}
							>
								<Glyph glyph={GLYPH_DELETE} />

								{#snippet popover_content(popover)}
									<button
										type="button"
										class="color_c icon_button bg_c_1"
										title="confirm delete"
										onclick={() => {
											// TODO async confirmation
											selected_model_detail &&
												void handle_delete_model(selected_model_detail.model_name);
											popover.hide();
										}}
									>
										<Glyph glyph={GLYPH_DELETE} />
									</button>
								{/snippet}
							</Confirm_Button>
						</div>
					</div>

					<!-- Model Details (always expanded) -->
					<Ollama_Model_Detail model_detail={selected_model_detail} {ollama} />
				</div>
			</div>
		{:else if selected_view === 'pull'}
			<div class="h_100 overflow_auto p_md">
				<Ollama_Pull_Model {ollama} onclose={handle_close_form} />
			</div>
		{:else if selected_view === 'create'}
			<div class="h_100 overflow_auto p_md">
				<Ollama_Create_Model {ollama} onclose={handle_close_form} />
			</div>
		{:else if selected_view === 'copy'}
			<div class="h_100 overflow_auto p_md">
				<Ollama_Copy_Model {ollama} onclose={handle_close_form} />
			</div>
		{/if}
	</div>
</div>
