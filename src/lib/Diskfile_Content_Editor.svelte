<script lang="ts">
	import {slide} from 'svelte/transition';
	import {format} from 'date-fns';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import {untrack} from 'svelte';

	import Content_Editor from '$lib/Content_Editor.svelte';
	import type {Diskfile} from '$lib/diskfile.svelte.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {Diskfile_Editor_State} from '$lib/diskfile_editor_state.svelte.js';
	import {GLYPH_PLACEHOLDER} from '$lib/glyphs.js';

	interface Props {
		diskfile: Diskfile;
		editor_state?: Diskfile_Editor_State;
		show_stats?: boolean;
		show_actions?: boolean;
		placeholder?: string;
		readonly?: boolean;
		attrs?: SvelteHTMLElements['textarea'];
	}

	const {
		diskfile,
		editor_state: editor_state_prop,
		show_stats = true,
		show_actions = false,
		placeholder,
		readonly = false,
		attrs,
	}: Props = $props();

	const zzz = zzz_context.get();

	// Create the editor state if not provided
	const editor_state = $derived(
		editor_state_prop ?? untrack(() => new Diskfile_Editor_State({zzz, diskfile})),
	);

	// Keep track of the content editor for focusing
	let content_editor: {focus: () => void} | undefined = $state();

	const handle_content_change = (content: string) => {
		editor_state.updated_content = content;
	};
</script>

<div class="h_100 column">
	<Content_Editor
		content={editor_state.updated_content}
		onchange={handle_content_change}
		placeholder={placeholder ?? GLYPH_PLACEHOLDER + ' ' + diskfile.pathname}
		{show_stats}
		{show_actions}
		{readonly}
		{attrs}
		bind:this={content_editor}
	/>

	{#if !readonly && editor_state.content_history.length > 1}
		<div class="history mt_xs" transition:slide={{duration: 120}}>
			<details>
				<summary class="size_sm"
					>Edit History ({editor_state.content_history.length} entries)</summary
				>
				<menu class="unstyled flex flex_column mt_xs">
					{#each editor_state.content_history as entry (entry.created)}
						<button
							type="button"
							class="plain justify_content_space_between size_sm py_xs3"
							class:selected={entry.id === editor_state.selected_history_entry_id}
							onclick={() => {
								editor_state.set_content_from_history(entry.id);
								content_editor?.focus();
							}}
						>
							<span>{format(new Date(entry.created), 'HH:mm:ss')}</span>
							{#if entry.is_unsaved_edit}
								<span class="unsaved_tag">unsaved</span>
							{/if}
							<span>{entry.content.length} chars</span>
						</button>
					{/each}
				</menu>
			</details>
		</div>
	{/if}
</div>

<style>
	.history {
		border-top: 1px solid var(--border_color_1);
		padding-top: var(--space_xs);
	}

	summary {
		cursor: pointer;
	}

	.unsaved_tag {
		color: var(--color_c);
		font-size: 0.8em;
	}
</style>
