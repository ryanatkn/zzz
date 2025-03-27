<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Contextmenu_Diskfile from '$lib/Contextmenu_Diskfile.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_FILE} from '$lib/glyphs.js';

	interface Props {
		diskfile: Diskfile;
		selected?: boolean | undefined;
		onclick?: ((diskfile: Diskfile) => void) | undefined;
		compact?: boolean | undefined;
		attrs?: SvelteHTMLElements['button'] | undefined;
	}

	const {diskfile, selected, onclick, compact = true, attrs}: Props = $props();

	// TODO BLOCK change to links like the others, probably
</script>

<Contextmenu_Diskfile {diskfile}>
	<button
		type="button"
		class="listitem"
		{...attrs}
		class:selected
		class:compact
		onclick={onclick ? () => onclick(diskfile) : undefined}
		title="file at {diskfile.path}"
	>
		<div class="ellipsis">
			<Glyph icon={GLYPH_FILE} />
			<span
				>{#if diskfile.path_relative}{diskfile.path_relative}{:else}<Pending_Animation />{/if}</span
			>
		</div>
	</button>
</Contextmenu_Diskfile>
