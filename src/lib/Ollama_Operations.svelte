<script lang="ts">
	// @slop claude_sonnet_4

	import {slide} from 'svelte/transition';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {Unreachable_Error} from '@ryanatkn/belt/error.js';

	import Glyph from '$lib/Glyph.svelte';
	import {
		GLYPH_DOWNLOAD,
		GLYPH_ADD,
		GLYPH_COPY,
		GLYPH_DELETE,
		GLYPH_CHECKMARK,
		GLYPH_ERROR,
		GLYPH_CLEAR,
		GLYPH_INFO,
	} from '$lib/glyphs.js';
	import type {Ollama, Ollama_Operation_Type} from '$lib/ollama.svelte.js';
	import {format_timestamp} from '$lib/time_helpers.js';

	interface Props {
		ollama: Ollama;
	}

	const {ollama}: Props = $props();

	const get_operation_icon = (type: Ollama_Operation_Type) => {
		switch (type) {
			case 'pull':
				return GLYPH_DOWNLOAD;
			case 'create':
				return GLYPH_ADD;
			case 'copy':
				return GLYPH_COPY;
			case 'delete':
				return GLYPH_DELETE;
			case 'list':
			case 'show':
				return GLYPH_INFO;
			default:
				throw new Unreachable_Error(type);
		}
	};

	const get_operation_color = (status: string) => {
		switch (status) {
			case 'success':
				return 'color_b';
			case 'failure':
				return 'color_c';
			case 'pending':
				return 'color_d';
			default:
				return '';
		}
	};
</script>

<div class="panel p_md width_md" transition:slide>
	<div class="display_flex justify_content_space_between align_items_center mb_md">
		<h4 class="mt_0 mb_0">operations</h4>
		<div class="display_flex gap_xs">
			{#if ollama.completed_operations.length > 0}
				<button
					type="button"
					class="icon_button plain font_size_sm"
					title="clear completed operations"
					onclick={() => ollama.clear_completed_operations()}
				>
					<Glyph glyph={GLYPH_CLEAR} />
				</button>
			{/if}
		</div>
	</div>

	<ul class="unstyled">
		<!-- All Operations (most recent first) -->
		<!-- TODO use indexed collection probably, with normal sorting/filtering patterns -->
		{#each Array.from(ollama.operations.values()).reverse() as operation (operation.id)}
			<li transition:slide class="py_xs3">
				<div
					class="display_flex justify_content_space_between align_items_center p_sm border_radius_xs {operation.status ===
					'pending'
						? 'bg_2'
						: 'bg_1'} {get_operation_color(operation.status)}"
				>
					<div class="display_flex gap_sm align_items_center">
						{#if operation.status === 'pending'}
							<Pending_Animation />
						{:else}
							<Glyph glyph={operation.status === 'success' ? GLYPH_CHECKMARK : GLYPH_ERROR} />
						{/if}
						<Glyph glyph={get_operation_icon(operation.type)} />
						<div class="font_weight_600">{operation.type}</div>
						{#if operation.model}
							<div class="flex_1 font_family_mono font_size_sm ellipsis">
								<div class="ellipsis">{operation.model}</div>
							</div>
						{/if}
						{#if operation.status === 'failure' && operation.error_message}
							<div class="font_size_sm">- {operation.error_message}</div>
						{/if}
					</div>
					<span class="font_size_sm">
						{format_timestamp(operation.updated_date.getTime())}
					</span>
				</div>
			</li>
		{/each}
	</ul>
</div>
