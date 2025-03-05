<script lang="ts">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import {onNavigate} from '$app/navigation';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {base} from '$app/paths';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import {is_editable, swallow} from '@ryanatkn/belt/dom.js';

	import {zzz_context} from '$lib/zzz.svelte.js';
	import Settings from '$lib/Settings.svelte';

	interface Props {
		disabled?: boolean;
	}

	const {disabled}: Props = $props();

	const zzz = zzz_context.get();

	onNavigate(() => {
		if (zzz.ui.show_main_dialog) zzz.toggle_main_menu(false);
	});
</script>

<svelte:window
	onkeydowncapture={disabled
		? undefined
		: (e) => {
				if (e.key === '`' && !is_editable(e.target)) {
					zzz.toggle_main_menu();
					swallow(e);
				}
			}}
/>

{#if !disabled && zzz.ui.show_main_dialog}
	<Dialog onclose={() => zzz.toggle_main_menu(false)} layout="page">
		<div class="pane">
			<section class="p_xl box">
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
