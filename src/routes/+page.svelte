<script lang="ts">
	import {base} from '$app/paths';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import Page_Footer from '$routes/Page_Footer.svelte';

	// TODO remove this after fixing
	// class:row
	// class:content
	// class:icon
	// class:title

	import Dashboard_Home from '$lib/Dashboard_Home.svelte';
</script>

<section class="row gap_xl5 mb_xl5">
	<div>
		<Svg data={zzz_logo} size="var(--icon_size_xl2)" attrs={{class: 'mt_xl5'}} />
	</div>
	<div>
		<p style:padding-top="132px">Zzz is a fullstack toolkit for adaptive web environments.</p>
		<p>
			It's an early work in progress with more on the way. See <a href="{base}/about">/about</a>.
		</p>
	</div>
</section>

<Dashboard_Home />

<Page_Footer />
