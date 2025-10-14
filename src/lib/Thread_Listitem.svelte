<script lang="ts">
	import type {Chat} from '$lib/chat.svelte.js';
	import type {Thread} from '$lib/thread.svelte.js';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';
	import Confirm_Button from '$lib/Confirm_Button.svelte';
	import Thread_Contextmenu from '$lib/Thread_Contextmenu.svelte';
	import Provider_Logo from '$lib/Provider_Logo.svelte';
	import Thread_Toggle_Button from '$lib/Thread_Toggle_Button.svelte';
	import Glyph from '$lib/Glyph.svelte';

	const {
		thread,
		chat,
	}: {
		thread: Thread;
		chat: Chat;
	} = $props();

	const turn_count = $derived(thread.turns.size);

	// TODO hacky but is the desired UX for now
	const selectable = $derived(chat.view_mode === 'simple');
	const selected = $derived(selectable && chat.selected_thread_id === thread.id);
</script>

<Thread_Contextmenu {thread}>
	<!-- svelte-ignore a11y_no_noninteractive_tabindex -->
	<div
		class="thread_listitem p_xs2"
		class:dormant={!thread.enabled}
		class:selected
		onclick={selectable ? () => chat.select_thread(thread.id) : undefined}
		onkeydown={selectable ? (e) => e.key === 'Enter' && chat.select_thread(thread.id) : undefined}
		role={selectable ? 'button' : undefined}
		tabindex={selectable ? 0 : undefined}
	>
		<div class="row justify_content_space_between gap_xs">
			<div class="flex_1">
				<div class="font_weight_400">
					<Provider_Logo name={thread.model.provider_name} size="var(--font_size_md)" />
					{thread.model_name}
				</div>
				<div class="display_flex gap_xs">
					{#if turn_count > 0}
						<small
							>{turn_count} message{turn_count !== 1 ? 's' : ''}, {thread.token_count} token{thread.token_count !==
							1
								? 's'
								: ''}</small
						>
					{:else}&nbsp;{/if}
				</div>
			</div>
			<div class="display_flex gap_xs">
				<Thread_Toggle_Button {thread} />
				<Confirm_Button
					onconfirm={() => chat.remove_thread(thread.id)}
					class="icon_button plain"
					title="delete thread"
				>
					<Glyph glyph={GLYPH_REMOVE} />
				</Confirm_Button>
			</div>
		</div>
	</div>
</Thread_Contextmenu>

<style>
	/* TODO hacky styles, see usage, extract reusable parts (classes/components and border variables) */
	.thread_listitem {
		border-radius: var(--border_radius_xs);
		border: var(--border_width_2) var(--border_style) transparent;
	}
	.thread_listitem.selected {
		border-color: var(--border_color_a);
	}
	.thread_listitem:hover {
		background-color: var(--bg_1);
	}
</style>
