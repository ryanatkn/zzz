<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';
	import {slide} from 'svelte/transition';

	import {zzz_context} from '$lib/zzz.svelte.js';

	// interface Props {}

	// const {}: Props = $props();

	const zzz = zzz_context.get();

	let echo_text = $state('echo server ⚞');

	const send_echo = () => {
		zzz.send_echo(echo_text || 'ping');
	};

	const echos = $derived(zzz.echos.slice().reverse());

	const remaining_placeholders = $derived(Math.max(0, zzz.echos_max_length - zzz.echos.length));
</script>

<div class="row gap_sm">
	<input
		bind:value={echo_text}
		onkeydown={(e) => {
			if (e.key === 'Enter') send_echo();
		}}
		placeholder="enter text to echo"
	/>
	<button
		type="button"
		onclick={() => {
			send_echo();
		}}>echo</button
	>
</div>
<ul class="unstyled column reverse p_md">
	{#each echos as echo (echo)}
		{@const elapsed = zzz.echo_elapsed.get(echo.id)}
		<li class="row ellipsis" transition:slide>
			<small>
				{#if elapsed}{elapsed}ms{:else}<Pending_Animation />{/if}
			</small>
			<div class="ellipsis pl_md">{echo.data}</div>
		</li>
	{/each}
	{#each {length: remaining_placeholders} as _}
		<li class="row" style:opacity="0.2" transition:slide><div>&nbsp;</div></li>
	{/each}
</ul>
