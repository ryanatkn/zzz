<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import Contextmenu_Diskfile from '$lib/Contextmenu_Diskfile.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {GLYPH_FILE} from '$lib/glyphs.js';

	interface Props {
		diskfile: Diskfile;
		selected: boolean;
		onclick: (file: Diskfile) => void;
	}

	const {diskfile, selected, onclick}: Props = $props();

	// TODO BLOCK change to links like the others, probably
</script>

<Contextmenu_Diskfile {diskfile}>
	<button
		type="button"
		class="button_list_item compact"
		class:selected
		onclick={() => onclick(diskfile)}
		title="file at {diskfile.path}"
	>
		<div class="ellipsis">
			<Glyph_Icon icon={GLYPH_FILE} />
			<span
				>{#if diskfile.path_relative}{diskfile.path_relative}{:else}<Pending_Animation />{/if}</span
			>
		</div>
	</button>
</Contextmenu_Diskfile>
