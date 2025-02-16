<script lang="ts">
	import Nav_Link from './Nav_Link.svelte';

	import {base} from '$app/paths';
	import type {Snippet} from 'svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import Svg from '@ryanatkn/fuz/Svg.svelte';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();
</script>

<!-- TODO drive with data -->
<div class="flex h_100">
	<div class="h_100 relative" style:width="200px">
		<!-- TODO refactor -->
		<div class="sidebar absolute t_0 l_0 h_100 w_100 p_md">
			<nav class="column size_lg">
				<div class="flex mb_sm">
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
				<Nav_Link href="{base}/chats">chats</Nav_Link>
				<Nav_Link href="{base}/files">files</Nav_Link>
				<!-- <a href="{base}/pages" class:selected={page.url.pathname === base + '/pages'}>pages</a>
				<a href="{base}/lists" class:selected={page.url.pathname === base + '/lists'}>lists</a>
				<a href="{base}/posts" class:selected={page.url.pathname === base + '/posts'}>posts</a>
				<a href="{base}/cells" class:selected={page.url.pathname === base + '/cells'}>cells</a> OR "data" -->

				<!-- Collaboration -->
				<!-- <h3>Collaboration</h3>
				<a href="{base}/people" class:selected={page.url.pathname === base + '/people'}>people</a>
				<a href="{base}/spaces" class:selected={page.url.pathname === base + '/spaces'}>spaces</a> -->

				<!-- AI Tools -->
				<h3 class="mb_xs">AI</h3>
				<Nav_Link href="{base}/providers">providers</Nav_Link>
				<Nav_Link href="{base}/models">models</Nav_Link>
				<!-- <a href="{base}/experiments" class:selected={page.url.pathname === base + '/experiments'}
					>experiments</a
				>
				<a href="{base}/agents" class:selected={page.url.pathname === base + '/agents'}>agents</a> -->

				<!-- System -->
				<h3 class="mb_xs">System</h3>
				<Nav_Link href="{base}/about">about</Nav_Link>
				<Nav_Link href="{base}/capabilities">capabilities</Nav_Link>
				<!-- TODO more - terminal, account -->
				<Nav_Link href="{base}/settings">settings</Nav_Link>
			</nav>
		</div>
	</div>
	<div class="flex_1 h_100">
		{@render children()}
	</div>
</div>

<style>
	/* TODO maybe move this concern? */
	:global(body, html) {
		height: 100%;
	}

	a {
		display: flex;
	}
</style>
