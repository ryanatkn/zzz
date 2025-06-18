<script lang="ts">
	import {slide} from 'svelte/transition';

	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import {GLYPH_FILE} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import {zzz_context} from '$lib/frontend.svelte.js';
	import type {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import Diskfile_Metrics from '$lib/Diskfile_Metrics.svelte';
	import {has_dependencies} from '$lib/diskfile_helpers.js';

	interface Props {
		diskfile: Diskfile;
		editor_state: Diskfile_Editor_State;
	}

	const {diskfile, editor_state}: Props = $props();

	const app = zzz_context.get();
</script>

<div class="display_flex flex_column gap_xs w_100">
	<small class="overflow_wrap_break_all w_100">
		<Glyph glyph={GLYPH_FILE} />{app.diskfiles.to_relative_path(diskfile.path)}
	</small>

	<small class="font_family_mono">
		<div>created {diskfile.created_formatted_datetime}</div>
		<div>updated {diskfile.updated_formatted_date}</div>
	</small>

	<Diskfile_Metrics {editor_state} />

	{#if has_dependencies(diskfile)}
		<small class="font_family_mono" transition:slide>
			<div>{diskfile.dependencies_count} dependencies</div>
			<div>{diskfile.dependents_count} dependents</div>
		</small>
	{/if}

	<small class="font_family_mono">{diskfile.id}</small>
</div>
