<script lang="ts">
	import {resolve} from '$app/paths';
	import Svg from '@fuzdev/fuz_ui/Svg.svelte';

	import PageFooter from '$routes/PageFooter.svelte';

	import {logo_zzz} from '$lib/logos.js';
	import DashboardHome from '$lib/DashboardHome.svelte';
</script>

<section class="row gap_xl5 mb_xl5">
	<div>
		<Svg data={logo_zzz} size="var(--icon_size_xl2)" attrs={{class: 'mt_xl5'}} />
	</div>
	<div>
		<div class="row mt_xl5 mb_lg">
			<blockquote>nice web things for the tired 💤</blockquote>
		</div>
		<p>Zzz is a local-first forge for power users and devs.</p>
		<p>
			It's an early work in progress, see the <a href={resolve('/about')}>about page</a> and
			<a href={resolve('/docs')}>docs</a>.
		</p>
	</div>
</section>

<DashboardHome />

<PageFooter />
