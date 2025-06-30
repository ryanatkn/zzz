<script lang="ts">
	import {tick} from 'svelte';
	import {swallow} from '@ryanatkn/belt/dom.js';
	import type {SvelteHTMLElements} from 'svelte/elements';

	// TODO either refactor to support Textarea or make that a separate Editable_Textarea

	// TODO maybe rewrite with contenteditable, be less opinionated

	interface Props {
		value: string;
		// TODO maybe support `onsave`, but `bind:` now supports this easily enough
		// onsave: (value: string) => void;
		attrs?: SvelteHTMLElements['span'];
		span_attrs?: SvelteHTMLElements['span'];
		input_attrs?: SvelteHTMLElements['input'];
	}

	let {value = $bindable(), attrs, span_attrs, input_attrs}: Props = $props();

	let is_editing = $state(false);
	let edited_value = $state('');
	let input_el: HTMLInputElement | undefined = $state();
	let span_el: HTMLSpanElement | undefined = $state();

	const save = () => {
		const trimmed = edited_value.trim(); // TODO parse with an optional zod schema
		if (!trimmed) {
			is_editing = false;
			return;
		}
		value = trimmed;
		is_editing = false;
		finalize_editing();
	};

	const cancel = () => {
		is_editing = false;
		edited_value = '';
		finalize_editing();
	};

	const start_editing = () => {
		is_editing = true;
		edited_value = value;
		void tick().then(() => input_el?.select());
	};

	const finalize_editing = () => {
		void tick().then(() => span_el?.focus());
	};

	// TODO maybe export the classes as module-scoped constants?
</script>

{#if is_editing}
	<input
		type="text"
		{...attrs}
		{...input_attrs}
		bind:this={input_el}
		bind:value={edited_value}
		onblur={save}
		onkeydown={(event) => {
			const {key} = event;
			if (key === 'Enter' || key === 'F2') {
				swallow(event);
				save();
			} else if (key === 'Escape') {
				swallow(event);
				cancel();
			}
		}}
	/>
{:else}
	<span
		role="button"
		tabindex="0"
		aria-label="click to edit"
		{...attrs}
		{...span_attrs}
		bind:this={span_el}
		onclick={start_editing}
		onkeydown={(event) => {
			const {key} = event;
			if (key === 'Enter' || key === ' ' || key === 'F2') {
				swallow(event);
				start_editing();
			}
		}}
	>
		<span class="ellipsis">
			{value}
		</span>
	</span>
{/if}

<style>
	input {
		flex: 1;
		padding: 0 var(--space_xs);
		margin: 0;
	}
	span[role='button'] {
		display: inline-flex;
		align-items: center;
		height: var(--input_height);
		border-radius: var(--border_radius_xs);
		cursor: text;
		flex: 1;
		padding: 0 var(--space_xs);
		overflow: hidden; /* for ellipsis, is there another way to force it to shrink to obscure content? */
	}
	span[role='button']:hover {
		background-color: var(--bg_6);
	}
</style>
