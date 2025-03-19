<script lang="ts">
	import {scale, slide} from 'svelte/transition';
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';
	import {encode as tokenize} from 'gpt-tokenizer';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import type {Tape} from '$lib/tape.svelte.js';
	import Strip_Item from '$lib/Strip_Item.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import {Scrollable} from '$lib/scrollable.svelte.js';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import {GLYPH_PLACEHOLDER} from '$lib/glyphs.js';

	interface Props {
		tape: Tape;
		onremove: () => void;
		onsend: (input: string) => Promise<void>;
	}

	const {tape, onremove, onsend}: Props = $props();

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
		pending = true;
		await onsend(parsed);
		pending = false;
	};

	const scrollable = new Scrollable();

	// Handle content change
	const handle_input_change = (content: string) => {
		input = content;
	};

	// TODO BLOCK add reset button

	// TODO BLOCK edit individual items in the list (contextmenu too - show contextmenu target outline)

	// TODO BLOCK show pending animation - it should first create the strip in the pending Async_Status

	// TODO BLOCK the link should instead be a model picker (dialog? or overlaid without a bg maybe?)
</script>

<!-- TODO `duration_2` is the Moss variable for 200ms and 1 for 80ms, but it's not in a usable form -->
<div class="chat_tape" transition:scale={{duration: 200}}>
	<div class="flex justify_content_space_between">
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
		<Confirm_Button
			onconfirm={onremove}
			attrs={{
				class: 'plain compact',
				title: `delete tape with ${tape.model_name} and ${tape.token_count} tokens`,
			}}
		/>
	</div>

	<div class="strips" use:scrollable.container use:scrollable.target>
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
			content={input}
			onchange={handle_input_change}
			placeholder={GLYPH_PLACEHOLDER}
			show_stats
			show_actions
			bind:this={content_input}
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

<style>
	.chat_tape {
		padding: var(--space_md);
		display: flex;
		flex-direction: column;
		gap: var(--space_md);
		background-color: var(--bg);
		border-radius: var(--radius_xs);
	}
	.strips {
		display: flex;
		flex-direction: column-reverse; /* makes scrolling start at the bottom */
		gap: 0.5rem;
		max-height: 400px;
		overflow: auto;
		scrollbar-width: thin;
	}
</style>
