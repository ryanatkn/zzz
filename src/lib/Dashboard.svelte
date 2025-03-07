<script lang="ts">
	import {base} from '$app/paths';
	import type {Snippet} from 'svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import Svg from '@ryanatkn/fuz/Svg.svelte';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {
		GLYPH_CAPABILITY,
		GLYPH_CHAT,
		GLYPH_FILE,
		GLYPH_MESSAGE,
		GLYPH_MODEL,
		GLYPH_PROMPT,
		GLYPH_PROVIDER,
		GLYPH_SETTINGS,
	} from '$lib/glyphs.js';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	const SIDEBAR_WIDTH_MAX = 200;
	const sidebar_width = $state(SIDEBAR_WIDTH_MAX);

	// TODO dashboard should be mounted with Markdown
</script>

<!-- TODO drive with data -->
<div class="dashboard" style:--sidebar_width="{sidebar_width}px">
	<div class="h_100 w_100 fixed t_0 l_0" style:padding-left="var(--sidebar_width)">
		{@render children()}
	</div>
	<div
		class="h_100 fixed t_0 l_0 overflow_auto scrollbar_width_thin"
		style:width="var(--sidebar_width)"
	>
		<!-- TODO refactor -->
		<div class="p_sm">
			<!-- TODO support `max_height_100` in Moss -->
			<nav class="size_lg">
				<div class="flex p_sm mb_sm">
					<Nav_Link
						href="{base}/"
						attrs={{
							title: 'home',
							style: 'width: auto; background: transparent',
							class: 'click_effect_scale',
						}}
					>
						<Svg data={zzz_logo} size="var(--icon_size_md)" />
					</Nav_Link>
				</div>
				<!-- Content -->
				<Nav_Link href="{base}/chats"
					><Glyph_Icon icon={GLYPH_CHAT} attrs={{class: 'icon_xs'}} /> chats</Nav_Link
				>
				<Nav_Link href="{base}/prompts"
					><Glyph_Icon icon={GLYPH_PROMPT} attrs={{class: 'icon_xs'}} /> prompts</Nav_Link
				>
				<Nav_Link href="{base}/files"
					><Glyph_Icon icon={GLYPH_FILE} attrs={{class: 'icon_xs'}} /> files</Nav_Link
				>

				<!-- <h3>Website</h3> <a href="{base}/pages" class:selected={page.url.pathname === base + '/pages'}>pages</a>
				<a href="{base}/lists" class:selected={page.url.pathname === base + '/lists'}>lists</a>
				<a href="{base}/posts" class:selected={page.url.pathname === base + '/posts'}>posts</a>
				<a href="{base}/cells" class:selected={page.url.pathname === base + '/cells'}>cells</a> OR "data" -->

				<!-- <h3>Collaboration</h3>
				<a href="{base}/people" class:selected={page.url.pathname === base + '/people'}>people</a>
				<a href="{base}/spaces" class:selected={page.url.pathname === base + '/spaces'}>spaces</a> -->

				<!-- AI Tools -->
				<div class="size_xl font_serif mt_xl7 mb_md text_color_3 font_weight_400">AI</div>
				<Nav_Link href="{base}/models"
					><Glyph_Icon icon={GLYPH_MODEL} attrs={{class: 'icon_xs'}} /> models</Nav_Link
				>
				<Nav_Link href="{base}/providers"
					><Glyph_Icon icon={GLYPH_PROVIDER} attrs={{class: 'icon_xs'}} /> providers</Nav_Link
				>
				<!-- <a href="{base}/experiments" class:selected={page.url.pathname === base + '/experiments'}
					>experiments</a
				>
				<a href="{base}/providers" class:selected={page.url.pathname === base + '/provider'}>providers</a> -->

				<!-- System -->
				<div class="size_xl font_serif mt_xl7 mb_md text_color_3 font_weight_400">System</div>
				<Nav_Link href="{base}/about">
					{#snippet children(selected)}<span class="icon_xs"
							><Svg
								data={zzz_logo}
								fill={selected ? 'var(--color_a_6)' : 'var(--text_color_1)'}
								size="var(--icon_size_xs)"
							/></span
						> about{/snippet}</Nav_Link
				>
				<Nav_Link href="{base}/messages"
					><Glyph_Icon icon={GLYPH_MESSAGE} attrs={{class: 'icon_xs'}} /> messages</Nav_Link
				>
				<Nav_Link href="{base}/capabilities"
					><Glyph_Icon icon={GLYPH_CAPABILITY} attrs={{class: 'icon_xs'}} /> capabilities</Nav_Link
				>
				<!-- TODO more - terminal, database, account, internals? -->
				<Nav_Link href="{base}/settings"
					><Glyph_Icon icon={GLYPH_SETTINGS} attrs={{class: 'icon_xs'}} /> settings</Nav_Link
				>
			</nav>
		</div>
	</div>
</div>
