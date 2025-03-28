<script lang="ts">
	import {slide} from 'svelte/transition';
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';
	import {encode as tokenize} from 'gpt-tokenizer';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import type {Tape} from '$lib/tape.svelte.js';
	import Strip_Item from '$lib/Strip_Item.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import {Scrollable} from '$lib/scrollable.svelte.js';
	import Contextmenu_Tape from '$lib/Contextmenu_Tape.svelte';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import {GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import type {SvelteHTMLElements} from 'svelte/elements';

	interface Props {
		tape: Tape;
		onremove: () => void;
		onsend: (input: string) => Promise<void>;
		show_delete_button?: boolean | undefined;
		strips_attrs?: SvelteHTMLElements['div'] | undefined;
		attrs?: SvelteHTMLElements['div'] | undefined;
	}

	const {tape, onremove, onsend, show_delete_button, strips_attrs, attrs}: Props = $props();

	let input = $state('');
	const input_tokens = $derived(tokenize(input));
	let content_input: {focus: () => void} | undefined;
	let pending = $state(false);

	const send = async () => {
		const parsed = input.trim();
		if (!parsed) {
			content_input?.focus();
			return;
		}
		input = '';
		setTimeout(() => content_input?.focus()); // timeout is maybe unnecessary, lets the input clear first to maybe avoid a frame of jank
		pending = true;
		await onsend(parsed);
		pending = false;
	};

	const scrollable = new Scrollable();

	// TODO BLOCK add reset button

	// TODO BLOCK edit individual items in the list (contextmenu too - show contextmenu target outline)

	// TODO BLOCK show pending animation - it should first create the strip in the pending Async_Status

	// TODO BLOCK the link should instead be a model picker (dialog? or overlaid without a bg maybe?)
</script>

<Contextmenu_Tape {tape}>
	<div {...attrs} class="chat_tape {attrs?.class}">
		<div class="flex justify_content_space_between align_items_start">
			<header>
				<div class="size_lg">
					<Model_Link model={tape.model} icon />
				</div>
				<small
					><Provider_Link
						provider={tape.zzz.providers.find_by_name(tape.model.provider_name)}
						icon="glyph"
						show_name
					/></small
				>
			</header>
			{#if show_delete_button}
				<Confirm_Button
					onconfirm={onremove}
					attrs={{
						class: 'plain compact',
						title: `delete tape with ${tape.model_name} and ${tape.token_count} tokens`,
					}}
				/>
			{/if}
		</div>

		<div
			{...strips_attrs}
			class="strips flex_1 {strips_attrs?.class}"
			use:scrollable.container
			use:scrollable.target
		>
			<ul class="unstyled">
				{#each tape.strips as strip (strip.id)}
					<li transition:slide>
						<Strip_Item {strip} />
					</li>
				{/each}
			</ul>
		</div>

		<div>
			<Content_Editor
				bind:this={content_input}
				bind:content={input}
				token_count={input_tokens.length}
				placeholder={GLYPH_PLACEHOLDER}
				show_stats
				show_actions
			>
				<Pending_Button
					{pending}
					onclick={send}
					attrs={{class: 'plain'}}
					title="send {input_tokens.length} tokens to {tape.model_name}"
				>
					send
				</Pending_Button>
			</Content_Editor>
		</div>
	</div>
</Contextmenu_Tape>

<style>
	.chat_tape {
		display: flex;
		flex-direction: column;
		gap: var(--space_md);
		background-color: var(--bg);
		border-radius: var(--radius_xs);
	}
	.strips {
		display: flex;
		flex-direction: column-reverse; /* makes scrolling start at the bottom */
		overflow: auto;
		scrollbar-width: thin;
	}
</style>
