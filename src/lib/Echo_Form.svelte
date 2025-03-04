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
{#if zzz.echos.length > 0}
	<ul class="unstyled column reverse p_md">
		{#each zzz.echos as echo (echo)}
			{@const elapsed = zzz.echo_elapsed.get(echo.id)}
			<li class="row" transition:slide>
				<small>
					{#if elapsed}{elapsed}ms{:else}<Pending_Animation />{/if}
				</small>
				<div class="ellipsis pl_md" style:max-width="200px">{echo.data}</div>
			</li>
		{/each}
	</ul>
{/if}
