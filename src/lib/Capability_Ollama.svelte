<script lang="ts">
	import {slide} from 'svelte/transition';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {onMount} from 'svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Glyph from '$lib/Glyph.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import {
		GLYPH_CONNECT,
		GLYPH_MODEL,
		GLYPH_PROVIDER,
		GLYPH_REFRESH,
		GLYPH_RESET,
	} from '$lib/glyphs.js';
	import Error_Message from '$lib/Error_Message.svelte';
	import {OLLAMA_URL} from '$lib/ollama.js';
	import External_Link from '$lib/External_Link.svelte';

	const zzz = zzz_context.get();
	const {capabilities} = zzz;

	// Initial load when component mounts
	onMount(() => {
		void capabilities.init_ollama_check();
	});
</script>

<div class="flex flex_column gap_md">
	<div class="flex gap_sm align_items_start">
		<div
			class="flex_1 chip plain flex_1 font_size_xl flex_column"
			style:display="flex !important"
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
				<small class="font_family_mono">{OLLAMA_URL}</small>
			</div>
		</div>

		<div class="flex_1 p_md">
			Ollama (<External_Link href="https://ollama.com/">ollama.com</External_Link>,
			<External_Link href="https://github.com/ollama/ollama">GitHub</External_Link>) is a local
			model server that forks
			<External_Link href="https://github.com/ggml-org/llama.cpp">llama.cpp</External_Link>. It's
			one of Zzz's first integrations but will be one of many supported local backends. See also the <Provider_Link
				provider={zzz.providers.find_by_name('ollama')}
				><span class="white_space_nowrap"><Glyph glyph={GLYPH_PROVIDER} /> Ollama</span> provider</Provider_Link
			> page.
		</div>
	</div>

	{#if capabilities.ollama.error_message}
		<div transition:slide>
			<Error_Message
				><small class="font_family_mono">{capabilities.ollama.error_message}</small></Error_Message
			>
		</div>
	{/if}

	<div class="flex justify_content_space_between gap_md">
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
					<div class="inline_flex align_items_end">
						checking <div class="relative"><Pending_Animation /></div>
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
			class="flex_1 justify_content_start"
			disabled={capabilities.ollama.status === 'initial'}
			onclick={() => capabilities.reset_ollama()}
		>
			<Glyph glyph={GLYPH_RESET} size="var(--font_size_xl)" />
			<span class="font_size_lg font_weight_400 ml_md"> reset </span>
		</button>
	</div>

	<!-- TODO UI to manage models -->

	{#if capabilities.ollama_models.length > 0}
		<div class="panel p_md" transition:slide>
			<h4 class="mt_0 mb_sm"><Glyph glyph={GLYPH_MODEL} /> models installed locally</h4>
			<ul class="unstyled">
				{#each capabilities.ollama_models as ollama_model (ollama_model.name)}
					{@const model = zzz.models.find_by_name(ollama_model.name)}
					<li class="p_xs">
						{#if model}<Model_Link {model} />{:else}{ollama_model.name}{/if}
						<div class="font_family_mono font_size_sm">{ollama_model.size} MB</div>
					</li>
				{/each}
			</ul>
		</div>
	{:else if capabilities.ollama.status === 'success' && capabilities.ollama.data?.list_response?.models.length === 0}
		<div class="panel p_md" transition:slide>
			<p>No models found. You can install models using the Ollama CLI.</p>
		</div>
	{/if}

	<div>TODO add a ui to manage models</div>
</div>
