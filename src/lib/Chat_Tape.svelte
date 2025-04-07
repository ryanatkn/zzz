<script lang="ts">
	import {slide} from 'svelte/transition';
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';
	import {encode as tokenize} from 'gpt-tokenizer';

	import type {Tape} from '$lib/tape.svelte.js';
	import Strip_Item from '$lib/Strip_Item.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import {Scrollable} from '$lib/scrollable.svelte.js';
	import Contextmenu_Tape from '$lib/Contextmenu_Tape.svelte';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import {GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import type {SvelteHTMLElements} from 'svelte/elements';
	import Tape_Toggle_Button from '$lib/Tape_Toggle_Button.svelte';

	interface Props {
		tape: Tape;
		onsend: (input: string) => Promise<void>;
		strips_attrs?: SvelteHTMLElements['div'] | undefined;
		attrs?: SvelteHTMLElements['div'] | undefined;
	}

	const {tape, onsend, strips_attrs, attrs}: Props = $props();

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

	const {strips} = $derived(tape);
	const strip_count = $derived(strips.length);

	// TODO BLOCK edit individual items in the list (contextmenu too - show contextmenu target outline)

	// TODO BLOCK show pending animation - it should first create the strip in the pending Async_Status

	// TODO BLOCK the link should instead be a model picker (dialog? or overlaid without a bg maybe?)
</script>

<Contextmenu_Tape {tape}>
	<div
		{...attrs}
		class="chat_tape {attrs?.class}"
		class:empty={!strip_count}
		class:dormant={!tape.enabled}
	>
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
			<div class="flex gap_xs">
				<Tape_Toggle_Button {tape} />
			</div>
		</div>

		{#if strip_count}
			<div
				{...strips_attrs}
				class="strips flex_1 radius_xs2 {strips_attrs?.class}"
				use:scrollable.container
				use:scrollable.target
			>
				<ul class="unstyled">
					{#each strips as strip (strip.id)}
						<li transition:slide>
							<Strip_Item {strip} />
						</li>
					{/each}
				</ul>
			</div>
		{/if}

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

	.chat_tape.empty {
		justify-content: center;
	}

	.strips {
		display: flex;
		flex-direction: column-reverse; /* makes scrolling start at the bottom */
		overflow: auto;
		scrollbar-width: thin;
	}
</style>
