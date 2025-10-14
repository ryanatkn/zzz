<script lang="ts">
	import {slide} from 'svelte/transition';

	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import {GLYPH_FILE} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import {frontend_context} from '$lib/frontend.svelte.js';
	import type {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import Diskfile_Metrics from '$lib/Diskfile_Metrics.svelte';
	import {has_dependencies} from '$lib/diskfile_helpers.js';

	const {
		diskfile,
		editor_state,
	}: {
		diskfile: Diskfile;
		editor_state: Diskfile_Editor_State;
	} = $props();

	const app = frontend_context.get();
</script>

<div class="display_flex flex_direction_column gap_xs width_100">
	<small class="overflow_wrap_break_all width_100">
		<Glyph glyph={GLYPH_FILE} />{app.diskfiles.to_relative_path(diskfile.path)}
	</small>

	<small>
		<div>created {diskfile.created_formatted_datetime}</div>
		{#if diskfile.updated_formatted_datetime !== diskfile.created_formatted_datetime}
			<div transition:slide>updated {diskfile.updated_formatted_datetime}</div>
		{/if}
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
