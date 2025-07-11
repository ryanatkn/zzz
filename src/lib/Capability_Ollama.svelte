<script lang="ts">
	// @slop Claude Sonnet 3.7

	import {slide} from 'svelte/transition';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {onMount} from 'svelte';
	import {plural} from '@ryanatkn/belt/string.js';

	import {frontend_context} from '$lib/frontend.svelte.js';
	import Glyph from '$lib/Glyph.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import {
		GLYPH_ARROW_RIGHT,
		GLYPH_CONNECT,
		GLYPH_MODEL,
		GLYPH_PROVIDER,
		GLYPH_REFRESH,
		GLYPH_RESET,
	} from '$lib/glyphs.js';
	import Error_Message from '$lib/Error_Message.svelte';
	import External_Link from '$lib/External_Link.svelte';
	import Ollama_Ps_Status from '$lib/Ollama_Ps_Status.svelte';

	const app = frontend_context.get();
	const {capabilities, ollama} = app;

	onMount(() => {
		void capabilities.init_ollama_check();

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

<div class="display_flex flex_column">
	<div class="py_sm display_flex gap_sm align_items_start">
		<div class="flex_1">
			<div
				class="w_100 chip plain flex_1 font_size_xl flex_column mb_lg"
				style:display="display_flex !important"
				style:align-items="flex-start !important"
				style:font-weight="400 !important"
				class:color_b={capabilities.ollama.status === 'success'}
				class:color_c={capabilities.ollama.status === 'failure'}
				class:color_d={capabilities.ollama.status === 'pending'}
				class:color_e={capabilities.ollama.status === 'initial'}
			>
				<div class="column justify_content_center gap_xs pl_md" style:min-height="80px">
					ollama {capabilities.ollama.status === 'success'
						? 'available'
						: capabilities.ollama.status === 'failure'
							? 'unavailable'
							: capabilities.ollama.status === 'pending'
								? 'checking'
								: 'not checked'}
					<span class="font_family_mono font_size_sm"
						>{ollama.host}
						{#if capabilities.ollama.data?.round_trip_time}<span
								><Glyph glyph={GLYPH_ARROW_RIGHT} />
								{Math.round(capabilities.ollama.data.round_trip_time)}ms</span
							>{/if}</span
					>
				</div>
			</div>
			<div class="py_sm display_flex justify_content_space_between gap_md">
				<button
					type="button"
					class="flex_1 justify_content_start"
					disabled={capabilities.ollama.status === 'pending'}
					onclick={() => capabilities.check_ollama()}
				>
					<Glyph
						glyph={capabilities.ollama.status === 'success' ? GLYPH_REFRESH : GLYPH_CONNECT}
						size="var(--font_size_xl)"
					/>
					<span class="font_size_lg font_weight_400 ml_md">
						{#if capabilities.ollama.status === 'pending'}
							<div class="display_inline_flex align_items_end">
								checking <div class="position_relative"><Pending_Animation /></div>
							</div>
						{:else if capabilities.ollama.status === 'success'}
							refresh
						{:else}
							check connection
						{/if}
					</span>
				</button>
				<button
					type="button"
					class="justify_content_start"
					disabled={capabilities.ollama.status === 'initial'}
					onclick={() => capabilities.reset_ollama()}
				>
					<Glyph glyph={GLYPH_RESET} size="var(--font_size_xl)" />
					<span class="font_size_lg font_weight_400 ml_md"> reset </span>
				</button>
			</div>
		</div>

		<div class="flex_1 px_md">
			Ollama (<External_Link href="https://ollama.com/">ollama.com</External_Link>,
			<External_Link href="https://github.com/ollama/ollama">GitHub</External_Link>) is a local
			model server that forks
			<External_Link href="https://github.com/ggml-org/llama.cpp">llama.cpp</External_Link>. It's
			one of Zzz's first integrations and the plan is to support many other local LLM backends
			(input/feedback is welcome). See also the <Provider_Link
				provider={app.providers.find_by_name('ollama')}
				><span class="white_space_nowrap"><Glyph glyph={GLYPH_PROVIDER} /> Ollama</span> provider</Provider_Link
			> page.
		</div>
	</div>

	{#if capabilities.ollama.error_message}
		<div class="py_sm" transition:slide>
			<Error_Message
				><small class="font_family_mono">{capabilities.ollama.error_message}</small></Error_Message
			>
		</div>
	{/if}

	<!-- Running models status -->
	{#if capabilities.ollama.status === 'success'}
		<div transition:slide class="py_sm">
			<Ollama_Ps_Status {ollama} />
		</div>
	{/if}

	<!-- Models list -->
	{#if capabilities.ollama.status !== 'initial' && capabilities.ollama_models.length > 0}
		<div transition:slide class="py_sm">
			<div class="panel p_md">
				<h4 class="mt_0 mb_sm">
					<Glyph glyph={GLYPH_MODEL} />
					{capabilities.ollama_models.length} model{plural(capabilities.ollama_models.length)} installed
					locally
				</h4>
				<ul class="unstyled">
					{#each capabilities.ollama_models as ollama_model (ollama_model.name)}
						{@const model = app.models.find_by_name(ollama_model.name)}
						<li class="p_xs">
							{#if model}<Model_Link {model} />{:else}{ollama_model.name}{/if}
							<div class="font_family_mono font_size_sm">{ollama_model.size} MB</div>
						</li>
					{/each}
				</ul>
			</div>
		</div>
	{:else if capabilities.ollama.status === 'success' && capabilities.ollama.data?.list_response?.models.length === 0}
		<div transition:slide class="py_sm">
			<div class="panel p_md">
				<p>no models found - for now you can install models using the Ollama CLI</p>
			</div>
		</div>
	{/if}

	<p>
		Full controls are on the <Provider_Link provider={app.providers.find_by_name('ollama')}
			><span class="white_space_nowrap"><Glyph glyph={GLYPH_PROVIDER} /> Ollama</span> provider</Provider_Link
		> page.
	</p>
</div>
