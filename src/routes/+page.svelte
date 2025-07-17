<script lang="ts">
	import {base} from '$app/paths';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import Footer from '$lib/Footer.svelte';

	// TODO remove this after fixing
	// class:row
	// class:content
	// class:icon
	// class:title

	import Dashboard_Home from '$lib/Dashboard_Home.svelte';
</script>

<section class="box">
	<Svg data={zzz_logo} size="var(--icon_size_xl2)" attrs={{class: 'my_xl5'}} />
	<p class="mt_xl3">nice web things for the tired 💤</p>
	<p class="mt_xl3 width_sm">
		Zzz is a fullstack toolkit for adaptive web environments. It's an early work in progress, see <a
			href="{base}/about">/about</a
		>.
	</p>
</section>

<Dashboard_Home />

<div class="box py_xl9">
	<Footer />
</div>
