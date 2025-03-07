<script lang="ts">
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import {GLYPH_FILE} from '$lib/glyphs.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {to_root_path} from '$lib/path.js';

	interface Props {
		file: Diskfile;
	}

	const {file}: Props = $props();
</script>

<div class="flex flex_column gap_xs">
	<small class="overflow_wrap_break_word">
		<Glyph_Icon icon={GLYPH_FILE} />
		{to_root_path(file.path)}
	</small>
	<small class="font_mono">{file.id}</small>
	<small class="font_mono">{file.contents_token_count} tokens</small>
	<small class="font_mono">{file.content_length} characters </small>
	<small class="font_mono">{file.dependencies_count} dependencies </small>
	<small class="font_mono">{file.dependents_count} dependents </small>
	<small class="font_mono">created {file.created_formatted_date}</small>
	<small class="font_mono">updated {file.updated_formatted_date}</small>
</div>
