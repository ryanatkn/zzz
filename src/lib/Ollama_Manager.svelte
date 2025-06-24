<script lang="ts">
	// @slop claude_sonnet_4

	import {slide} from 'svelte/transition';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {onMount} from 'svelte';
	import {plural} from '@ryanatkn/belt/string.js';

	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_COPY, GLYPH_ADD, GLYPH_DOWNLOAD, GLYPH_SETTINGS} from '$lib/glyphs.js';
	import Ollama_Configure from '$lib/Ollama_Configure.svelte';
	import Ollama_Model_Details from '$lib/Ollama_Model_Details.svelte';
	import Ollama_Pull_Model from '$lib/Ollama_Pull_Model.svelte';
	import Ollama_Create_Model from '$lib/Ollama_Create_Model.svelte';
	import Ollama_Copy_Model from '$lib/Ollama_Copy_Model.svelte';
	import type {Ollama, Ollama_Model_Detail} from '$lib/ollama.svelte.js';

	interface Props {
		ollama: Ollama;
	}

	const {ollama}: Props = $props();

	// TODO think about snapshotting/loading this and ollama.svelte.ts data

	// TODO probably should use routes instead of internal state, but I want to see about using this as a snapshotting experiment

	let selected_view: 'configure' | 'model' | 'pull' | 'create' | 'copy' = $state('configure');
	let selected_model_detail: Ollama_Model_Detail | null = $state(null as any);
	let last_active_view: {view: string; model_detail: Ollama_Model_Detail | null} | null =
		$state(null);

	// Initial load when component mounts
	onMount(() => {
		void ollama.refresh();
	});

	const set_view = (view: typeof selected_view, model_detail?: Ollama_Model_Detail | null) => {
		// Store the previous view as the last active view if it's not 'configure'
		if (selected_view !== 'configure' && selected_view !== view) {
			last_active_view = {
				view: selected_view,
				model_detail: selected_model_detail,
			};
		}
		selected_view = view;
		if (model_detail !== undefined) {
			selected_model_detail = model_detail;
		}
	};

	const handle_back_to_last_view = () => {
		if (last_active_view) {
			const view_to_restore = last_active_view;
			last_active_view = null; // Clear history
			selected_view = view_to_restore.view as typeof selected_view;
			selected_model_detail = view_to_restore.model_detail;
		}
	};

	const handle_delete_model = async (model_name: string) => {
		console.log(`[Ollama_Manager] deleting model: ${model_name}`);
		await ollama.delete_model(model_name);
		// Clear selection if the deleted model was selected
		if (selected_model_detail?.model_name === model_name) {
			set_view('configure', null);
		}
	};

	const handle_select_model = async (model_detail: Ollama_Model_Detail) => {
		set_view('model', model_detail);
		// Auto-load details if not already loaded
		if (model_detail.show_status === 'initial') {
			await ollama.show_model(model_detail.model_name);
		}
	};

	const handle_show_pull = () => {
		set_view('pull', null);
	};

	const handle_show_create = () => {
		set_view('create', null);
	};

	const handle_show_copy = () => {
		set_view('copy', null);
	};

	const handle_close_form = () => {
		set_view('configure', null);
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
								Ollama {ollama.list_status === 'success'
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
									{#if ollama.list_error}attempted{:else}refreshed{/if}
									{ollama.last_refreshed_from_now}
								</div>
							{/if}
						</div>
					</div>
				</div>

				<!-- TODO hacky styles, trying a variant of menu styles here, some of which may be upstreamed (plain doesnt currently mix well with others like menu_item and colors) -->
				<div class="flex_column gap_sm">
					<button
						type="button"
						class="w_100 justify_content_start border_radius_0 plain menu_item selectable font_weight_500"
						class:selected={selected_view === 'configure'}
						onclick={() => {
							set_view('configure', null);
						}}
					>
						<Glyph glyph={GLYPH_SETTINGS} />
						<span class="ml_sm">configure</span>
					</button>

					<button
						type="button"
						class="w_100 justify_content_start border_radius_0 plain menu_item selectable font_weight_500"
						class:selected={selected_view === 'pull'}
						disabled={!ollama.available}
						onclick={handle_show_pull}
					>
						<Glyph glyph={GLYPH_DOWNLOAD} />
						<span class="ml_sm">pull model</span>
					</button>

					<button
						type="button"
						class="w_100 justify_content_start border_radius_0 plain menu_item selectable font_weight_500"
						class:selected={selected_view === 'create'}
						disabled={!ollama.available}
						onclick={handle_show_create}
					>
						<Glyph glyph={GLYPH_ADD} />
						<span class="ml_sm">create model</span>
					</button>

					<button
						type="button"
						class="w_100 justify_content_start border_radius_0 plain menu_item selectable font_weight_500"
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
					<h3 class="mt_xl3 mb_md">
						{ollama.models_count} model{plural(ollama.models_count)}
					</h3>

					<div class="column">
						{#each ollama.models_with_details as model_detail (model_detail.model_name)}
							<button
								type="button"
								class="menu_item selectable plain text_align_start p_sm border_radius_0 font_weight_400"
								class:selected={selected_view === 'model' &&
									selected_model_detail?.model_name === model_detail.model_name}
								onclick={() => handle_select_model(model_detail)}
							>
								<div class="display_flex flex_column gap_xs w_100">
									<div class="ellipsis font_size_lg">
										{model_detail.model_name}
									</div>
									<div class="font_size_sm">
										{model_detail.model_response
											? Math.round(model_detail.model_response.size / (1024 * 1024))
											: '?'} MB
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
	<div class="flex_1 h_100 overflow_auto p_md">
		{#if selected_view === 'configure'}
			<Ollama_Configure
				{ollama}
				last_active_view={last_active_view?.view ?? null}
				onback={handle_back_to_last_view}
			/>
		{:else if selected_view === 'model' && selected_model_detail}
			<Ollama_Model_Details
				model_detail={selected_model_detail}
				{ollama}
				onclose={handle_close_form}
				ondelete={handle_delete_model}
			/>
		{:else if selected_view === 'pull'}
			<Ollama_Pull_Model {ollama} onclose={handle_close_form} />
		{:else if selected_view === 'create'}
			<Ollama_Create_Model {ollama} onclose={handle_close_form} />
		{:else if selected_view === 'copy'}
			<Ollama_Copy_Model {ollama} onclose={handle_close_form} />
		{/if}
	</div>
</div>
