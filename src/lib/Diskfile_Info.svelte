<script lang="ts">
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import {GLYPH_FILE} from '$lib/glyphs.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		file: Diskfile;
	}

	const {file}: Props = $props();

	const zzz = zzz_context.get();
</script>

<div class="flex flex_column gap_xs">
	<small class="overflow_wrap_break_word">
		<Glyph_Icon icon={GLYPH_FILE} />{zzz.diskfiles.to_relative_path(file.path)}
	</small>
	<small class="font_mono">{file.id}</small>
	<small class="font_mono">{file.contents_token_count} tokens</small>
	<small class="font_mono">{file.content_length} characters </small>
	<small class="font_mono">{file.dependencies_count} dependencies </small>
	<small class="font_mono">{file.dependents_count} dependents </small>
	<small class="font_mono">created {file.created_formatted_date}</small>
	<small class="font_mono">updated {file.updated_formatted_date}</small>
</div>
