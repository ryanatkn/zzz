<script lang="ts">
	import {page} from '$app/state';
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
			<nav>
				<!-- TODO what else? pages? data/cells? lists? (specialization of "cells"/"data") -->
				<a href="{base}/" class:selected={page.url.pathname === base + '/'} title="home">
					<Svg data={zzz_logo} size="var(--icon_size_md)" />
				</a>
			</nav>
			<nav class="column size_lg">
				<!-- Content -->
				<a href="{base}/chats" class:selected={page.url.pathname === base + '/chats'}>chats</a>
				<a href="{base}/files" class:selected={page.url.pathname === base + '/files'}>files</a>
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
				<a href="{base}/providers" class:selected={page.url.pathname === base + '/providers'}
					>providers</a
				>
				<a href="{base}/models" class:selected={page.url.pathname === base + '/models'}>models</a>
				<!-- <a href="{base}/experiments" class:selected={page.url.pathname === base + '/experiments'}
					>experiments</a
				>
				<a href="{base}/agents" class:selected={page.url.pathname === base + '/agents'}>agents</a> -->

				<!-- System -->
				<h3 class="mb_xs">System</h3>
				<a href="{base}/about" class:selected={page.url.pathname === base + '/about'}>about</a>
				<a href="{base}/system" class:selected={page.url.pathname === base + '/system'}>settings</a>
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
