<script lang="ts">
	import type {Chat} from '$lib/chat.svelte.js';
	import type {Tape} from '$lib/tape.svelte.js';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Tape_Contextmenu from '$lib/Tape_Contextmenu.svelte';
	import Provider_Logo from '$lib/Provider_Logo.svelte';
	import Tape_Toggle_Button from '$lib/Tape_Toggle_Button.svelte';
	import Glyph from '$lib/Glyph.svelte';

	const {
		tape,
		chat,
	}: {
		tape: Tape;
		chat: Chat;
	} = $props();

	const strip_count = $derived(tape.strips.size);

	// TODO BLOCK move to a class and add selection behavior for tapes even in multi view
	const selected = $derived(
		chat.view_mode === 'simple' && chat.tapes.length > 1 && chat.tapes[0].id === tape.id,
	);
</script>

<Tape_Contextmenu {tape}>
	<div class="tape_listitem p_xs2" class:dormant={!tape.enabled} class:selected>
		<div class="row justify_content_space_between gap_xs">
			<div class="flex_1">
				<div class="font_weight_600">
					<Provider_Logo name={tape.model.provider_name} size="var(--font_size_md)" />
					{tape.model_name}
				</div>
				<div class="display_flex gap_xs">
					{#if strip_count > 0}
						<small
							>{strip_count} message{strip_count !== 1 ? 's' : ''}, {tape.token_count} token{tape.token_count !==
							1
								? 's'
								: ''}</small
						>
					{:else}&nbsp;{/if}
				</div>
			</div>
			<div class="display_flex gap_xs">
				<Tape_Toggle_Button {tape} />
				<Confirm_Button
					onconfirm={() => chat.remove_tape(tape.id)}
					class="icon_button plain"
					title="delete tape"
				>
					<Glyph glyph={GLYPH_REMOVE} />
				</Confirm_Button>
			</div>
		</div>
	</div>
</Tape_Contextmenu>

<style>
	/* TODO hacky styles, see usage, extract reusable parts (classes/components and border variables) */
	.tape_listitem {
		border-radius: var(--border_radius_xs);
		border: var(--border_width_2) var(--border_style) transparent;
	}
	.tape_listitem.selected {
		border-color: var(--border_color_a);
	}
	.tape_listitem:hover {
		background-color: var(--bg_1);
	}
</style>
