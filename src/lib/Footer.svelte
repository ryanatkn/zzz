<script lang="ts">
	import Breadcrumb from '@ryanatkn/fuz/Breadcrumb.svelte';
	import Docs_Footer from '@ryanatkn/fuz/Docs_Footer.svelte';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import {strip_start} from '@ryanatkn/belt/string.js';
	import {page} from '$app/state';
	import {base} from '$app/paths';

	import {pkg_context} from '$lib/pkg.js';

	const pkg = pkg_context.get();
</script>

<Docs_Footer {pkg}>
	<div class="mb_xl5">
		{#if strip_start(page.url.pathname, base) === '/'}
			<a href="{base}/about">{@render icon()}</a>
		{:else}
			<Breadcrumb>{@render icon()}</Breadcrumb>
		{/if}
	</div>
</Docs_Footer>

{#snippet icon()}<Svg data={zzz_logo} size="var(--icon_size_sm)" />{/snippet}
