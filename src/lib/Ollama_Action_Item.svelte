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
	import type {Action_Method} from '$lib/action_metatypes.js';
	import {format_timestamp} from '$lib/time_helpers.js';

	interface Props {
		action: Action;
	}

	const {action}: Props = $props();

	// TODO refactor these

	const get_operation_icon = (method: Action_Method) => {
		switch (method) {
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
	};

	const get_operation_color = (step: string) => {
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
	};

	// Extract model name from action input if available
	const get_model_name = (action: Action): string | undefined => {
		const input = action.action_event?.input;
		if (input && typeof input === 'object' && 'model' in input) {
			return (input as any).model;
		}
		return undefined;
	};

	// Get error message from action event
	const get_error_message = (action: Action): string | undefined => {
		const error = action.action_event?.error;
		if (error && typeof error === 'object' && 'message' in error) {
			return (error as any).message;
		}
		return undefined;
	};

	// TODO refactor
	const progress_percent = $derived.by(() => {
		const progress = action.action_event?.progress;
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
		return undefined;
	});
</script>

<li transition:slide class="py_xs3">
	<div
		class="border_radius_xs {action.pending ? 'bg_2' : 'bg_1'} {get_operation_color(
			action.action_event?.step || 'initial',
		)}"
	>
		<div class="display_flex justify_content_space_between align_items_center p_sm">
			<div class="display_flex gap_sm align_items_center">
				{#if action.pending}
					<Pending_Animation />
				{:else}
					<Glyph glyph={action.success ? GLYPH_CHECKMARK : GLYPH_XMARK} />
				{/if}
				<Glyph glyph={get_operation_icon(action.method)} />
				<div class="font_weight_600">{action.method}</div>
				{#if get_model_name(action)}
					<div class="flex_1 font_family_mono font_size_sm ellipsis">
						<div class="ellipsis">{get_model_name(action)}</div>
					</div>
				{/if}
				{#if action.failed && get_error_message(action)}
					<div class="font_size_sm">- {get_error_message(action)}</div>
				{/if}
			</div>
			<span class="font_size_sm">
				{format_timestamp(action.updated_date.getTime())}
			</span>
		</div>
		{#if progress_percent !== undefined}
			<div class="p_sm pt_0">
				<Progress_Bar value={progress_percent} />
			</div>
		{/if}
	</div>
</li>
