<script lang="ts">
	import {base} from '$app/paths';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import Card from '@ryanatkn/fuz/Card.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import {DEV} from 'esm-env';

	// TODO remove this after fixing
	// class:row
	// class:content
	// class:icon
	// class:title
</script>

<footer class="box py_xl9">
	<Svg data={zzz_logo} size="var(--icon_size_xl2)" classes="my_xl5" />
	<p class="mt_xl3">bot control web</p>
	<p class="mt_xl3">work in progress</p>
	{#if !DEV}
		<p>
			At the moment, Zzz only functions when run locally on your dev machine. The goal is to make it
			available in all contexts, but you gotta start somewhere.
		</p>
	{/if}
	<p><Card href="{base}/about" icon="?" align="right">about</Card></p>
</footer>
