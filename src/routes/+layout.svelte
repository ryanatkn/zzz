<script lang="ts">
	import '@ryanatkn/moss/style.css';
	import '@ryanatkn/moss/theme.css';
	import '$routes/moss.css';
	import '$routes/style.css';

	import Themed from '@ryanatkn/fuz/Themed.svelte';
	import type {Snippet} from 'svelte';
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import Contextmenu_Root from '@ryanatkn/fuz/Contextmenu_Root.svelte';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';
	import {parse_package_meta} from '@ryanatkn/gro/package_meta.js';

	import Settings from '$routes/Settings.svelte';
	import {Zzz} from '$lib/zzz.svelte.js';
	import Zzz_Root from '$lib/Zzz_Root.svelte';
	import {pkg_context} from '$routes/pkg.js';
	import {package_json, src_json} from '$routes/package.js';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	pkg_context.set(parse_package_meta(package_json, src_json));

	const zzz = new Zzz({
		//
	});
</script>

<svelte:head>
	<title>Zzz</title>
</svelte:head>

<svelte:body
	use:contextmenu_action={[
		{
			snippet: 'text',
			props: {
				content: 'Settings',
				icon: '?',
				run: () => {
					zzz.data.show_main_menu = true;
				},
			},
		},
		{
			snippet: 'text',
			props: {
				content: 'Reload',
				icon: '⟳',
				run: () => {
					location.reload();
				},
			},
		},
	]}
/>

<Zzz_Root {zzz}>
	<Themed>
		<Contextmenu_Root>
			{@render children()}
			{#if zzz.data.show_main_menu}
				<Dialog onclose={() => (zzz.data.show_main_menu = false)}>
					<div class="pane">
						<section class="width_md box pt_xl3">
							<h1>Zzz</h1>
							<p>electric buzz</p>
							<p>work in progress</p>
							<p>
								don't miss the <a href="https://github.com/ryanatkn/zzz/discussions">discussions</a>
							</p>
						</section>
						<Settings />
					</div>
				</Dialog>
			{/if}
		</Contextmenu_Root>
	</Themed>
</Zzz_Root>
