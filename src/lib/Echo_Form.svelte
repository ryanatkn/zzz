<script lang="ts">
	import Pending_Animation from '@ryanatkn/fuz/Pending_Animation.svelte';

	import {zzz_context} from '$lib/zzz.svelte.js';

	// interface Props {}

	// const {}: Props = $props();

	const zzz = zzz_context.get();

	let echo_text = $state('echo server');

	const send_echo = () => {
		zzz.send_echo(echo_text);
	};

	// TODO
</script>

<div class="row">
	<button type="button" onclick={send_echo}>⚏</button>
	<input
		bind:value={echo_text}
		onkeydown={(e) => {
			if (e.key === 'Enter') send_echo();
		}}
	/>
</div>
{#if zzz.echos.length > 0}
	<ul class="unstyled column reverse">
		{#each zzz.echos as echo (echo)}
			{@const elapsed = zzz.echo_elapsed.get(echo.id)}
			<li class="row justify_content_space_between">
				<div class="ellipsis" style:max-width="200px">{echo.data}</div>
				<span>
					{#if elapsed}{elapsed}ms{:else}<Pending_Animation />{/if}
				</span>
			</li>
		{/each}
	</ul>
{/if}
