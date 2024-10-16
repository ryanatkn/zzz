<script lang="ts">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import {onNavigate} from '$app/navigation';
	import {is_editable} from '@ryanatkn/belt/dom.js';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {base} from '$app/paths';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Settings from '$lib/Settings.svelte';

	// interface Props {}

	// const {}: Props = $props();

	const zzz = zzz_context.get();

	onNavigate(() => {
		if (zzz.data.show_main_menu) zzz.toggle_main_menu(false);
	});
</script>

<svelte:window
	onkeydown={(e) => {
		if (e.key === 'Escape' && !is_editable(e.target)) {
			zzz.toggle_main_menu();
		}
	}}
/>

{#if zzz.data.show_main_menu}
	<Dialog onclose={() => zzz.toggle_main_menu(false)} layout="page">
		<div class="pane">
			<section>
				<Settings />
			</section>
			<section class="box pb_xl7">
				<footer>
					<a class="row p_md" href="{base}/about"
						><Svg data={zzz_logo} size="var(--icon_size_md)" />
						<span class="size_lg ml_md">about</span></a
					>
				</footer>
			</section>
		</div>
	</Dialog>
{/if}
