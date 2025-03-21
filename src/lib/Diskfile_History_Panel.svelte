<script lang="ts">
	import type {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import {GLYPH_IMPORTANT} from '$lib/glyphs.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';

	interface Props {
		editor_state: Diskfile_Editor_State;
		on_accept_disk_changes?: () => void;
		on_reject_disk_changes?: () => void;
	}

	const {
		editor_state,
		on_accept_disk_changes = () => editor_state.accept_disk_changes(),
		on_reject_disk_changes = () => editor_state.reject_disk_changes(),
	}: Props = $props();
</script>

<div class="flex justify_content_space_between align_items_center mb_xs">
	<div class="row gap_sm scolor_c size_lg">
		<Glyph_Icon icon={GLYPH_IMPORTANT} size="var(--size_xl2)" /> file changed on disk
	</div>
</div>
<div class="column gap_xs">
	<div class="size_sm">The file has been modified outside of the editor.</div>
	<div class="flex gap_sm">
		<button type="button" class="flex_1 color_g" onclick={on_accept_disk_changes}>
			accept changes
		</button>
		<button type="button" class="flex_1 color_h" onclick={on_reject_disk_changes}>
			ignore state on disk
		</button>
	</div>
	<div class="size_sm">
		Accept to update your editor with the new content, ignore to keep your current version. Saving
		will also ignore the state on disk.
	</div>
</div>
