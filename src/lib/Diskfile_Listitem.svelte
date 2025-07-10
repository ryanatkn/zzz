<script lang="ts">
	import {swallow} from '@ryanatkn/belt/dom.js';

	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Diskfile_Contextmenu from '$lib/Diskfile_Contextmenu.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_FILE} from '$lib/glyphs.js';

	interface Props {
		diskfile: Diskfile;
		selected?: boolean | undefined;
		attrs?: Record<string, unknown>;
		/**
		 * `hard` indicates a "hard select" like a doubleclick or enter keypress.
		 */
		onselect?: (diskfile: Diskfile, hard: boolean) => void;
	}

	const {diskfile, selected = false, attrs, onselect}: Props = $props();

	// TODO add a visible status when open in a tab
</script>

<Diskfile_Contextmenu {diskfile}>
	<div
		role="button"
		tabindex="0"
		class="menu_item compact ellipsis cursor_pointer"
		class:selected
		{...attrs}
		onclick={onselect
			? (e) => {
					swallow(e);
					onselect(diskfile, e.detail === 2);
				}
			: undefined}
		onkeydown={onselect
			? (e) => {
					if (e.key === 'Enter' || e.key === ' ') {
						swallow(e);
						onselect(diskfile, true);
					}
				}
			: undefined}
		aria-label={diskfile.path_relative ?? undefined}
		aria-pressed={selected}
	>
		<small class="ellipsis">
			<Glyph glyph={GLYPH_FILE} />
			<span class="ml_xs">{diskfile.path_relative}</span>
		</small>
	</div>
</Diskfile_Contextmenu>
