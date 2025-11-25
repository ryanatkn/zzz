<script lang="ts">
	import {slide} from 'svelte/transition';
	import PendingAnimation from '@ryanatkn/fuz/PendingAnimation.svelte';

	import Glyph from '$lib/Glyph.svelte';
	import type {Action} from '$lib/action.svelte.js';
	import {
		get_glyph_for_action_method,
		get_glyph_for_action_kind,
		GLYPH_ERROR,
	} from '$lib/glyphs.js';
	import ActionContextmenu from '$lib/ActionContextmenu.svelte';

	const {
		action,
		selected = false,
		onselect,
	}: {
		action: Action;
		selected?: boolean;
		onselect?: ((action: Action) => void) | undefined;
	} = $props();
</script>

<!-- TODO hoist the transition? -->
<ActionContextmenu {action}>
	<button
		type="button"
		class="width_100 text_align_left justify_content_start py_xs px_md border_radius_0 border_style_none box_shadow_none"
		class:selected
		class:color_c={action.has_error}
		onclick={() => {
			onselect?.(action);
		}}
		transition:slide
	>
		<div class="font_weight_400 display_flex align_items_center gap_xs width_100">
			<Glyph glyph={get_glyph_for_action_method(action.method)} />
			<Glyph glyph={get_glyph_for_action_kind(action.kind)} />
			<span class="font_family_mono flex_1 ellipsis">{action.method}</span>
			{#if action.pending}
				<PendingAnimation inline />
			{:else if action.has_error}
				<Glyph class="color_c" glyph={GLYPH_ERROR} />
			{/if}
			<small class="font_family_mono ml_auto">{action.created_formatted_time}</small>
		</div>
	</button>
</ActionContextmenu>
