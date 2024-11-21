<script lang="ts">
	import type {Snippet} from 'svelte';

	import {hud_context} from '$lib/hud.svelte.js';
	import Hud_Dialog from '$lib/Hud_Dialog.svelte';

	interface Props {
		hud?: Snippet; // TODO maybe delete all of this, design still shaking out
		children: Snippet;
	}

	const {hud, children}: Props = $props();

	const hud_from_context = hud_context.get();

	const hud_snippet = $derived(hud ?? hud_from_context);
</script>

<Hud_Dialog />
{@render children()}
{#if hud_snippet}
	<div class="hud">
		{@render hud_snippet()}
	</div>
{/if}

<style>
	.hud {
		position: fixed;
		top: 0;
		left: 0;
		height: var(--input_height);
		width: 100%;
	}
</style>
