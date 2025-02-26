<script lang="ts">
	import {scale} from 'svelte/transition';
	import Copy_To_Clipboard from '@ryanatkn/fuz/Copy_To_Clipboard.svelte';
	import Paste_From_Clipboard from '@ryanatkn/fuz/Paste_From_Clipboard.svelte';
	import {encode} from 'gpt-tokenizer';

	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import type {Tape} from '$lib/tape.svelte.js';
	import Chat_Message from '$lib/Chat_Message.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import {providers_default} from '$lib/config.js';
	import {GLYPH_PROVIDER} from '$lib/constants.js';
	import Clear_Restore_Button from '$lib/Clear_Restore_Button.svelte';
	import Bit_Stats from '$lib/Bit_Stats.svelte';

	interface Props {
		tape: Tape;
		onremove: () => void;
		onsend: (input: string) => void;
	}

	const {tape, onremove, onsend}: Props = $props();

	let input = $state('');
	const input_tokens = $derived(encode(input));
	let input_el: HTMLTextAreaElement | undefined;

	const send = () => {
		const parsed = input.trim();
		if (!parsed) {
			input_el?.focus();
			return;
		}
		onsend(parsed);
		input = '';
	};

	// TODO BLOCK the link should instead be a model picker (dialog? or overlaid without a bg maybe?)
</script>

<!-- TODO `duration_2` is the Moss variable for 200ms and 1 for 80ms, but it's not in a usable form -->
<div class="chat_tape" transition:scale={{duration: 200}}>
	<div class="header">
		<header>
			<div class="size_lg"><Model_Link model={tape.model} /></div>
			<small
				><Provider_Link
					provider={providers_default.find((p) => p.name === tape.model.provider_name)!}
					>{GLYPH_PROVIDER} {tape.model.provider_name}</Provider_Link
				></small
			>
		</header>
		<Confirm_Button onclick={onremove} />
	</div>

	<div class="messages">
		{#each tape.messages as message (message.id)}
			<Chat_Message {message} />
		{/each}
	</div>

	<div>
		<div class="flex gap_xs2">
			<textarea
				class="plain flex_1 mb_0"
				bind:value={input}
				bind:this={input_el}
				placeholder="content..."
				onkeydown={(e) => e.key === 'Enter' && !e.shiftKey && (send(), e.preventDefault())}
			></textarea>
			<button type="button" class="plain" onclick={() => send()}>send</button>
		</div>
		<div class="flex my_xs">
			<Copy_To_Clipboard text={input} attrs={{class: 'plain', disabled: !input}} />
			<Paste_From_Clipboard
				onpaste={(text) => {
					input += text;
					input_el?.focus();
				}}
				attrs={{class: 'plain'}}
			/>
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
	.header {
		display: flex;
		justify-content: space-between;
	}
	.messages {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		max-height: 400px;
		overflow-y: auto;
	}
	textarea {
		height: 80px;
	}
</style>
