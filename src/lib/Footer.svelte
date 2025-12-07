<script lang="ts">
	import Breadcrumb from '@fuzdev/fuz_ui/Breadcrumb.svelte';
	import DocsFooter from '@fuzdev/fuz_ui/DocsFooter.svelte';
	import Svg from '@fuzdev/fuz_ui/Svg.svelte';
	import {zzz_logo} from '@fuzdev/fuz_ui/logos.js';
	import {page} from '$app/state';
	import {resolve} from '$app/paths';

	import {library_context} from './library.js';

	const library = library_context.get();
</script>

<DocsFooter {library}>
	<div class="mb_xl5">
		{#if page.url.pathname === resolve('/')}
			<a href={resolve('/about')}>{@render icon()}</a>
		{:else}
			<Breadcrumb>{@render icon()}</Breadcrumb>
		{/if}
	</div>
</DocsFooter>

{#snippet icon()}<Svg data={zzz_logo} size="var(--icon_size_sm)" />{/snippet}
