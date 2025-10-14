<script lang="ts">
	import {slide} from 'svelte/transition';
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import Glyph from '$lib/Glyph.svelte';
	import Progress_Bar from '$lib/Progress_Bar.svelte';
	import {
		GLYPH_DOWNLOAD,
		GLYPH_ADD,
		GLYPH_COPY,
		GLYPH_DELETE,
		GLYPH_CHECKMARK,
		GLYPH_INFO,
		GLYPH_XMARK,
	} from '$lib/glyphs.js';
	import type {Action} from '$lib/action.svelte.js';
	import {format_timestamp} from '$lib/time_helpers.js';

	const {
		action,
	}: {
		action: Action;
	} = $props();

	const {action_event_data} = $derived(action);

	const operation_icon = $derived.by(() => {
		switch (action.method) {
			case 'ollama_pull':
				return GLYPH_DOWNLOAD;
			case 'ollama_create':
				return GLYPH_ADD;
			case 'ollama_copy':
				return GLYPH_COPY;
			case 'ollama_delete':
				return GLYPH_DELETE;
			case 'ollama_list':
			case 'ollama_show':
			case 'ollama_ps':
			default:
				return GLYPH_INFO;
		}
	});

	const operation_color_class = $derived.by(() => {
		const step = action_event_data?.step || 'initial';
		switch (step) {
			case 'handled':
				return 'color_b';
			case 'failed':
				return 'color_c';
			case 'handling':
				return 'color_d';
			default:
				return '';
		}
	});

	const model_name = $derived.by(() => {
		const input = action_event_data?.input;
		if (input && typeof input === 'object' && 'model' in input) {
			return (input as any).model;
		}
		return undefined;
	});

	const error_message = $derived.by(() => {
		const error = action_event_data?.error;
		if (error && typeof error === 'object' && 'message' in error) {
			return (error as any).message;
		}
		return undefined;
	});

	const progress_percent = $derived.by(() => {
		const progress = action_event_data?.progress;
		if (
			progress &&
			typeof progress === 'object' &&
			'completed' in progress &&
			'total' in progress
		) {
			const completed = (progress as any).completed;
			const total = (progress as any).total;
			if (typeof completed === 'number' && typeof total === 'number' && total > 0) {
				return Math.round((completed / total) * 100);
			}
		}
		return null;
	});
</script>

<li transition:slide class="py_xs3">
	<div class="border_radius_xs {action.pending ? 'bg_2' : 'bg_1'} {operation_color_class}">
		<div class="display_flex justify_content_space_between align_items_center p_sm">
			<div class="display_flex gap_md align_items_center">
				{#if action.pending}
					<Pending_Animation />
				{:else}
					<Glyph
						glyph={action.success ? GLYPH_CHECKMARK : GLYPH_XMARK}
						class={action.failed ? 'color_c_5' : undefined}
					/>
				{/if}
				<Glyph glyph={operation_icon} />
				<div class="font_size_sm font_weight_600">{action.method}</div>
				{#if model_name}
					<div class="font_size_sm flex_1 font_family_mono ellipsis">
						<div class="ellipsis">{model_name}</div>
					</div>
				{/if}
				{#if action.failed && error_message}
					<div class="font_size_sm color_c_5 font_weight_500">{error_message}</div>
				{/if}
			</div>
			<span class="font_size_sm">
				{format_timestamp(action.updated_date.getTime())}
			</span>
		</div>
		{#if progress_percent !== null}
			<div class="p_sm pt_0">
				<Progress_Bar value={progress_percent} />
			</div>
		{/if}
	</div>
</li>
