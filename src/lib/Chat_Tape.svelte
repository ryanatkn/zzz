<script lang="ts">
	import {scale, slide} from 'svelte/transition';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Paste_From_Clipboard from '@ryanatkn/fuz/Paste_From_Clipboard.svelte';
	import {encode as tokenize} from 'gpt-tokenizer';
	import Pending_Button from '@ryanatkn/fuz/Pending_Button.svelte';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import type {Tape} from '$lib/tape.svelte.js';
	import Chat_Message_Item from '$lib/Chat_Message_Item.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';
	import Bit_Stats from '$lib/Bit_Stats.svelte';
	import Error_Message from '$lib/Error_Message.svelte';
	import {GLYPH_PASTE} from '$lib/glyphs.js';
	import {Scrollable} from '$lib/scrollable.svelte.js';

	interface Props {
		tape: Tape;
		onremove: () => void;
		onsend: (input: string) => Promise<void>;
	}

	const {tape, onremove, onsend}: Props = $props();

	let input = $state('');
	const input_tokens = $derived(tokenize(input));
	let input_el: HTMLTextAreaElement | undefined;
	let pending = $state(false);

	const send = async () => {
		const parsed = input.trim();
		if (!parsed) {
			input_el?.focus();
			return;
		}
		input = '';
		pending = true;
		await onsend(parsed);
		pending = false;
	};

	const tape_messages = $derived(tape.chat_messages);

	const scrollable = new Scrollable();

	// TODO BLOCK add reset button

	// TODO BLOCK edit individual items in the list (contextmenu too - show contextmenu target outline)

	// TODO BLOCK show pending animation - it should first create the message in the pending Async_Status

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
		<Confirm_Button onclick={onremove} />
	</div>

	<div class="messages" use:scrollable.container use:scrollable.target>
		{#if tape_messages}
			<ul class="unstyled">
				{#each tape_messages as message (message.id)}
					<li transition:slide>
						<Chat_Message_Item {message} />
					</li>
				{/each}
			</ul>
		{:else}
			<Error_Message>something went wrong getting this tape's messages</Error_Message>
		{/if}
	</div>

	<div>
		<div class="flex gap_xs2">
			<textarea
				class="plain flex_1 mb_0"
				bind:value={input}
				bind:this={input_el}
				placeholder="content..."
			></textarea>
			<Pending_Button {pending} onclick={send} attrs={{class: 'plain'}}>send</Pending_Button>
		</div>
		<div class="flex my_xs">
			<Copy_To_Clipboard text={input} attrs={{class: 'plain'}} />
			<Paste_From_Clipboard
				onpaste={(text) => {
					input += text;
					input_el?.focus();
				}}
				attrs={{class: 'plain icon_button size_lg', title: 'paste'}}
				>{GLYPH_PASTE}</Paste_From_Clipboard
			>
			<Clear_Restore_Button
				value={input}
				onchange={(value) => {
					input = value;
				}}
			/>
		</div>
		<Bit_Stats length={input.length} token_count={input_tokens.length} />
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
	.messages {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		max-height: 400px;
		overflow-y: auto;
		scrollbar-width: thin;
	}
	textarea {
		height: 80px;
	}
</style>
