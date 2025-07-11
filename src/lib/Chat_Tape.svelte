<script lang="ts">
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';
	import {tick} from 'svelte';
	import type {SvelteHTMLElements} from 'svelte/elements';

	import {estimate_token_count} from '$lib/helpers.js';
	import type {Tape} from '$lib/tape.svelte.js';
	import Model_Picker_Dialog from '$lib/Model_Picker_Dialog.svelte';
	import Strip_List from '$lib/Strip_List.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import Tape_Contextmenu from '$lib/Tape_Contextmenu.svelte';
	import Model_Contextmenu from '$lib/Model_Contextmenu.svelte';
	import Content_Editor from '$lib/Content_Editor.svelte';
	import {GLYPH_PLACEHOLDER} from '$lib/glyphs.js';

	// TODO no longer uses `Chat`, maybe rename to `Tape_View` or similar?

	interface Props {
		tape: Tape;
		onsend: (input: string) => Promise<void>;
		// TODO @many think about how these two could be refactored, like a single class instance
		focus_key?: string | number | null | undefined;
		pending_element_to_focus_key?: string | number | null | undefined;
		strips_attrs?: SvelteHTMLElements['div'] | undefined;
		attrs?: SvelteHTMLElements['div'] | undefined;
	}

	let {
		tape,
		onsend,
		focus_key,
		pending_element_to_focus_key = $bindable(),
		strips_attrs,
		attrs,
	}: Props = $props();

	let input = $state('');
	const input_token_count = $derived(estimate_token_count(input));
	let content_input: {focus: () => void} | undefined;
	let pending = $state(false);

	const send = async () => {
		const parsed = input.trim();
		if (!parsed) {
			content_input?.focus();
			return;
		}
		input = '';
		void tick().then(() => content_input?.focus()); // timeout is maybe unnecessary, lets the input clear first to maybe avoid a frame of jank
		pending = true;
		await onsend(parsed);
		pending = false;
	};

	const strip_count = $derived(tape.strips.size);

	const empty = $derived(!strip_count);

	let show_model_picker = $state(false);
</script>

<Model_Contextmenu model={tape.model}>
	<Tape_Contextmenu {tape}>
		<div {...attrs} class="chat_tape {attrs?.class}" class:empty class:dormant={!tape.enabled}>
			<div class="display_flex justify_content_space_between align_items_start">
				<header>
					<button
						type="button"
						class="plain compact font_size_lg text_align_left"
						onclick={() => (show_model_picker = true)}
					>
						{tape.model.name}
					</button>
					<small
						><Provider_Link
							provider={tape.app.providers.find_by_name(tape.model.provider_name)}
							icon="glyph"
							show_name
						/></small
					>
				</header>
				<!-- TODO maybe add a button here that opens the contextmenu? -->
			</div>

			{#if strip_count}
				<Strip_List {tape} attrs={strips_attrs} />
			{/if}

			<div>
				<Content_Editor
					bind:this={content_input}
					bind:content={input}
					token_count={input_token_count}
					placeholder={GLYPH_PLACEHOLDER}
					show_stats
					show_actions
					{focus_key}
					bind:pending_element_to_focus_key
				>
					<Pending_Button
						{pending}
						onclick={send}
						attrs={{class: 'plain'}}
						title="send {input_token_count} tokens to {tape.model_name}"
					>
						send
					</Pending_Button>
				</Content_Editor>
			</div>
		</div>

		<Model_Picker_Dialog
			bind:show={show_model_picker}
			onpick={(model) => {
				if (model) {
					tape.switch_model(model.id);
				}
			}}
		/>
	</Tape_Contextmenu>
</Model_Contextmenu>

<style>
	.chat_tape {
		display: flex;
		flex-direction: column;
		gap: var(--space_md);
		background-color: var(--bg);
		border-radius: var(--border_radius_xs);
	}

	.chat_tape.empty {
		justify-content: center;
	}
</style>
