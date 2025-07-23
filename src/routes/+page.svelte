<script lang="ts">
	import {base} from '$app/paths';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import Page_Footer from '$routes/Page_Footer.svelte';

	import Dashboard_Home from '$lib/Dashboard_Home.svelte';
</script>

<section class="row gap_xl5 mb_xl5">
	<div>
		<Svg data={zzz_logo} size="var(--icon_size_xl2)" attrs={{class: 'mt_xl5'}} />
	</div>
	<div>
		<div class="row mt_xl5 mb_lg">
			<blockquote>nice web things for the tired 💤</blockquote>
		</div>
		<p>Zzz is a fullstack web toolkit for power users and devs.</p>
		<p>It's an early work in progress with more on the way.</p>
		<p>More <a href="{base}/about">about Zzz</a>.</p>
	</div>
</section>

<Dashboard_Home />

<Page_Footer />
