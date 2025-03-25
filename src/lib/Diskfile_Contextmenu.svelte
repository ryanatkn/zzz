<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Contextmenu from '@ryanatkn/fuz/Contextmenu.svelte';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import {GLYPH_COPY, GLYPH_DELETE} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props extends Omit_Strict<ComponentProps<typeof Contextmenu>, 'entries'> {
		diskfile: Diskfile;
	}

	const {diskfile, ...rest}: Props = $props();

	const zzz = zzz_context.get();
</script>

<Contextmenu {...rest} {entries} />

{#snippet entries()}
	<!-- TODO add this contextmenu feature: disabled={!file.content} -->
	<Contextmenu_Entry
		run={async () => {
			if (diskfile.content) {
				await navigator.clipboard.writeText(diskfile.content);
			}
		}}
	>
		{#snippet icon()}{GLYPH_COPY}{/snippet}
		<span>copy file content <small class="ml_xs">{diskfile.content_preview}</small></span>
	</Contextmenu_Entry>

	<Contextmenu_Entry
		run={() => {
			// TODO BLOCK better confirmation
			// eslint-disable-next-line no-alert
			if (confirm(`Are you sure you want to delete ${diskfile.path_relative}?`)) {
				zzz.diskfiles.delete(diskfile.path);
			}
		}}
	>
		{#snippet icon()}{GLYPH_DELETE}{/snippet}
		<span>delete file</span>
	</Contextmenu_Entry>
{/snippet}
