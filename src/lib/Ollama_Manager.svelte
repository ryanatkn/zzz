<script lang="ts">
	// @slop claude_sonnet_4

	import {slide} from 'svelte/transition';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {onMount} from 'svelte';
	import {plural} from '@ryanatkn/belt/string.js';

	import Glyph from '$lib/Glyph.svelte';
	import External_Link from '$lib/External_Link.svelte';
	import {GLYPH_ADD, GLYPH_COPY, GLYPH_DOWNLOAD, GLYPH_SETTINGS} from '$lib/glyphs.js';
	import Ollama_Configure from '$lib/Ollama_Configure.svelte';
	import Ollama_Model_Details from '$lib/Ollama_Model_Details.svelte';
	import Ollama_Pull_Model from '$lib/Ollama_Pull_Model.svelte';
	import Ollama_Create_Model from '$lib/Ollama_Create_Model.svelte';
	import Ollama_Copy_Model from '$lib/Ollama_Copy_Model.svelte';
	import Ollama_Model_Listitem from '$lib/Ollama_Model_Listitem.svelte';
	import type {Ollama} from '$lib/ollama.svelte.js';

	interface Props {
		ollama: Ollama;
	}

	const {ollama}: Props = $props();

	// TODO consider "pinning" views so that when others open, they stay open and stable onscreen (but you probably want to rearrange the panels)

	// TODO think about snapshotting/loading this and ollama.svelte.ts data

	// TODO probably should use routes instead of internal state,
	// but I want to see about using this as a snapshotting experiment
	// (with saving/loading the full state, starting at the app, the tree root),
	// there are some nice properties of this approach,
	// that could probably be achieved in other ways too
	// like using SvelteKit's snapshots - https://svelte.dev/docs/kit/snapshots

	onMount(() => {
		void ollama.refresh();

		// TODO @many probably want a different state to capture user intent of enabling polling, but the whole UX may change
		// Start polling for `ps` status if not already started
		const started_polling = !ollama.ps_polling_enabled;
		if (started_polling) {
			ollama.start_ps_polling({immediate: false}); // refresh does this above
		}

		return started_polling
			? () => {
					ollama.stop_ps_polling();
				}
			: undefined;
	});
</script>

<div class="display_flex h_100">
	<!-- sidebar -->
	<div class="h_100 overflow_hidden width_sm min_width_sm">
		<div class="h_100 overflow_auto scrollbar_width_thin p_md">
			<!-- status and connection -->
			<section class="display_flex flex_column gap_md">
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
							<div class="font_family_mono font_size_sm">
								{ollama.host}
								{#if ollama.list_round_trip_time}
									<span> → {Math.round(ollama.list_round_trip_time)}ms</span>
								{/if}
							</div>
						</div>
					</div>
				</div>

				<!-- TODO hacky styles, trying a variant of menu styles here, some of which may be upstreamed (plain doesnt currently mix well with others like menu_item and colors) -->
				<div class="flex_column gap_sm">
					<button
						type="button"
						class="w_100 justify_content_start border_radius_0 plain menu_item selectable font_weight_500"
						class:selected={ollama.manager_selected_view === 'configure'}
						onclick={() => {
							ollama.set_manager_view('configure', null);
						}}
					>
						<Glyph glyph={GLYPH_SETTINGS} />
						<span class="ml_sm">configure</span>
					</button>

					<button
						type="button"
						class="w_100 justify_content_start border_radius_0 plain menu_item selectable font_weight_500"
						class:selected={ollama.manager_selected_view === 'pull'}
						disabled={!ollama.available}
						onclick={() => ollama.set_manager_view('pull', null)}
					>
						<Glyph glyph={GLYPH_DOWNLOAD} />
						<span class="ml_sm">pull model</span>
					</button>

					<button
						type="button"
						class="w_100 justify_content_start border_radius_0 plain menu_item selectable font_weight_500"
						class:selected={ollama.manager_selected_view === 'create'}
						disabled={!ollama.available}
						onclick={() => ollama.set_manager_view('create', null)}
					>
						<Glyph glyph={GLYPH_ADD} />
						<span class="ml_sm">create model</span>
					</button>

					<button
						type="button"
						class="w_100 justify_content_start border_radius_0 plain menu_item selectable font_weight_500"
						class:selected={ollama.manager_selected_view === 'copy'}
						disabled={!ollama.available || ollama.models_downloaded.length === 0}
						onclick={() => ollama.set_manager_view('copy', null)}
					>
						<Glyph glyph={GLYPH_COPY} />
						<span class="ml_sm">copy model</span>
					</button>
				</div>
			</section>

			{#if ollama.available}
				{#if ollama.models_downloaded.length > 0}
					<!-- downloaded mdels -->
					<section>
						<h3 class="mt_xl3 mb_md">
							{ollama.models_downloaded.length} model{plural(ollama.models_downloaded.length)}
						</h3>

						<div class="column">
							{#each ollama.models_downloaded as model (model.id)}
								<Ollama_Model_Listitem {model} />
							{/each}
						</div>
					</section>
					<!-- models not downloaded -->
					{#if ollama.models_not_downloaded.length > 0}
						<section>
							<h3 class="mt_xl3 mb_md">
								{ollama.models_not_downloaded.length} not downloaded
							</h3>

							<div class="column">
								{#each ollama.models_not_downloaded as model (model.id)}
									<Ollama_Model_Listitem
										{model}
										onclick={async () => {
											await model.navigate_to_download();
										}}
									/>
								{/each}
							</div>
						</section>
					{/if}
				{:else}
					<section class="panel p_md" transition:slide>
						<p>
							no models found, <button
								type="button"
								class="inline compact"
								disabled={ollama.manager_selected_view === 'pull'}
								onclick={() => ollama.set_manager_view('pull', null)}>pull a model</button
							>
							or install them using the
							<External_Link href="https://github.com/ollama/ollama">Ollama CLI</External_Link>
						</p>
					</section>
				{/if}
			{/if}
		</div>
	</div>

	<!-- main content -->
	<div class="flex_1 h_100 overflow_auto p_md">
		{#if ollama.manager_selected_view === 'configure'}
			<Ollama_Configure
				{ollama}
				last_active_view={ollama.manager_last_active_view?.view ?? null}
				onshowpull={() => ollama.set_manager_view('pull', null)}
				onback={() => ollama.manager_back_to_last_view()}
			/>
		{:else if ollama.manager_selected_view === 'model' && ollama.manager_selected_model}
			<div class="display_block panel p_md">
				<Ollama_Model_Details
					model={ollama.manager_selected_model}
					onshow={(m) => ollama.app.api.ollama_show({model: m.name})}
					onclose={() => ollama.close_form()}
					ondelete={(m) => ollama.delete(m.name)}
				/>
			</div>
		{:else if ollama.manager_selected_view === 'pull'}
			<Ollama_Pull_Model {ollama} oncancel={() => ollama.close_form()} />
		{:else if ollama.manager_selected_view === 'create'}
			<Ollama_Create_Model
				{ollama}
				onclose={() => ollama.close_form()}
				onshowpull={() => ollama.set_manager_view('pull', null)}
			/>
		{:else if ollama.manager_selected_view === 'copy'}
			<Ollama_Copy_Model {ollama} onclose={() => ollama.close_form()} />
		{/if}
	</div>
</div>
