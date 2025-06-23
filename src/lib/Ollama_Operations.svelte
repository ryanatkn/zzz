<!-- filepath: /home/ryan/dev/zzz/src/lib/Ollama_Operations.svelte -->
<script lang="ts">
	import {slide} from 'svelte/transition';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import Glyph from '$lib/Glyph.svelte';
	import {
		GLYPH_DOWNLOAD,
		GLYPH_ADD,
		GLYPH_COPY,
		GLYPH_DELETE,
		GLYPH_CHECK,
		GLYPH_ERROR,
		GLYPH_CLEAR,
	} from '$lib/glyphs.js';
	import type {Ollama} from '$lib/ollama.svelte.js';
	import {format_timestamp} from '$lib/time_helpers.js';

	interface Props {
		ollama: Ollama;
	}

	const {ollama}: Props = $props();

	const get_operation_icon = (type: string) => {
		switch (type) {
			case 'pull':
				return GLYPH_DOWNLOAD;
			case 'create':
				return GLYPH_ADD;
			case 'copy':
				return GLYPH_COPY;
			case 'delete':
				return GLYPH_DELETE;
			default:
				return GLYPH_CHECK;
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

<div class="panel p_md" transition:slide>
	<div class="display_flex justify_content_space_between align_items_center mb_md">
		<h4 class="mt_0 mb_0">Operations</h4>
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

	<div class="display_flex flex_column gap_sm">
		<!-- Pending Operations -->
		{#each ollama.pending_operations as operation (operation.id)}
			<div
				class="display_flex justify_content_space_between align_items_center p_sm border_radius_xs bg_2"
			>
				<div class="display_flex gap_sm align_items_center">
					<Pending_Animation />
					<Glyph glyph={get_operation_icon(operation.type)} />
					<span class="font_weight_600">{operation.type}</span>
					{#if operation.model}
						<span class="font_family_mono font_size_sm">{operation.model}</span>
					{/if}
				</div>
				<span class="font_size_sm text_color_dimmed">
					{format_timestamp(operation.created_date.getTime())}
				</span>
			</div>
		{/each}

		<!-- Completed Operations -->
		{#each ollama.completed_operations.slice(-10) as operation (operation.id)}
			<div
				class="display_flex justify_content_space_between align_items_center p_sm border_radius_xs bg_1 {get_operation_color(
					operation.status,
				)}"
			>
				<div class="display_flex gap_sm align_items_center">
					<Glyph glyph={operation.status === 'success' ? GLYPH_CHECK : GLYPH_ERROR} />
					<Glyph glyph={get_operation_icon(operation.type)} />
					<span class="font_weight_600">{operation.type}</span>
					{#if operation.model}
						<span class="font_family_mono font_size_sm">{operation.model}</span>
					{/if}
					{#if operation.status === 'failure' && operation.error_message}
						<span class="font_size_sm text_color_dimmed">- {operation.error_message}</span>
					{/if}
				</div>
				<span class="font_size_sm text_color_dimmed">
					{format_timestamp(operation.updated_date.getTime())}
				</span>
			</div>
		{/each}
	</div>
</div>
