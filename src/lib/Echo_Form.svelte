<script lang="ts">
	import {zzz_context} from '$lib/zzz.svelte.js';

	// interface Props {}

	// const {}: Props = $props();

	const zzz = zzz_context.get();

	let echo_text = $state('echo server');

	const send_echo = () => {
		zzz.client.send({type: 'echo', data: echo_text});
	};

	// TODO
</script>

<div class="row">
	<button type="button" onclick={send_echo}>⚏</button><input bind:value={echo_text} />
</div>
{#if zzz.echos.length > 0}
	<ul class="column reverse">
		{#each zzz.echos as echo (echo)}
			<li>{echo.data}</li>
		{/each}
	</ul>
{/if}
