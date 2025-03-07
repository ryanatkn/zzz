<script lang="ts">
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';
	import Contextmenu_Entry from '@ryanatkn/fuz/Contextmenu_Entry.svelte';

	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import {to_root_path} from '$lib/path.js';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {GLYPH_FILE, GLYPH_REMOVE, GLYPH_COPY} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		file: Diskfile;
		selected: boolean;
		onclick: (file: Diskfile) => void;
	}

	const {file, selected, onclick}: Props = $props();

	const zzz = zzz_context.get();

	// Computed properties
	const display_name = $derived(file.path ? to_root_path(file.path) : 'Unnamed file');

	// TODO BLOCK generic contextmenu entries for other components? so module scope export?
</script>

<button
	type="button"
	class="compact"
	class:selected
	onclick={() => onclick(file)}
	title="file at {file.path}"
	use:contextmenu_action={contextmenu_entries}
>
	<div class="ellipsis">
		<Glyph_Icon icon={GLYPH_FILE} />
		<span>{display_name}</span>
	</div>
</button>

{#snippet contextmenu_entries()}
	<!-- TODO add this contextmenu feature: disabled={!file.contents} -->
	<Contextmenu_Entry
		run={async () => {
			if (file.contents) {
				await navigator.clipboard.writeText(file.contents);
			}
		}}
	>
		{#snippet icon()}{GLYPH_COPY}{/snippet}
		<span>Copy contents</span>
	</Contextmenu_Entry>

	<Contextmenu_Entry
		run={() => {
			// TODO BLOCK better confirmation
			// eslint-disable-next-line no-alert
			if (confirm(`Are you sure you want to delete ${display_name}?`)) {
				zzz.diskfiles.delete(file.path);
			}
		}}
	>
		{#snippet icon()}{GLYPH_REMOVE}{/snippet}
		<span>Delete file</span>
	</Contextmenu_Entry>
{/snippet}

<style>
	button {
		width: 100%;
		border-radius: 0;
		word-break: break-all;
		justify-content: start;
		padding: 0 var(--space_xs);
		box-shadow: none;
		border: var(--border_width_1) solid transparent;
		font-weight: 400;
		font-size: var(--size_sm);
	}

	button.selected {
		--button_text_color: var(--text_color_1);
		--button_fill: var(--fg_2);
		--button_fill_hover: var(--fg_1);
		--button_fill_active: var(--fg_2);
		--button_border_color: var(--border_color_a);
	}
</style>
