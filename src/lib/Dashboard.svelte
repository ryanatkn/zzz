<script lang="ts">
	import {page} from '$app/state';
	import {base} from '$app/paths';
	import type {Snippet} from 'svelte';

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
				<a href="{base}/" class:selected={page.url.pathname === base + '/'}>home</a>
				<a href="{base}/chats" class:selected={page.url.pathname === base + '/chats'}>chats</a>
				<a href="{base}/files" class:selected={page.url.pathname === base + '/files'}>files</a>
				<a href="{base}/models" class:selected={page.url.pathname === base + '/models'}>models</a>
				<a href="{base}/system" class:selected={page.url.pathname === base + '/system'}>system</a>
			</nav>
		</div>
	</div>
	<div class="flex_1 h_100">
		{@render children()}
	</div>
</div>
