<script lang="ts">
	import {base} from '$app/paths';

	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	// TODO remove this after fixing
	// class:row
	// class:content
	// class:icon
	// class:title

	import Dashboard_Home from '$lib/Dashboard_Home.svelte';
</script>

<Dashboard_Home />

<footer class="box py_xl9">
	<Svg data={zzz_logo} size="var(--icon_size_xl2)" attrs={{class: 'my_xl5'}} />
	<p class="mt_xl3">bot and web toolkit 💤 bot control web</p>
	<p class="mt_xl3">work in progress, see <a href="{base}/about">/about</a></p>
</footer>
