<script lang="ts">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import {onNavigate} from '$app/navigation';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {base} from '$app/paths';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		disabled?: boolean | undefined;
	}

	const {disabled}: Props = $props();

	const zzz = zzz_context.get();

	onNavigate(() => {
		if (zzz.ui.show_main_dialog) zzz.ui.toggle_main_menu(false);
	});
</script>

{#if !disabled && zzz.ui.show_main_dialog}
	<Dialog onclose={() => zzz.ui.toggle_main_menu(false)} layout="page">
		<div class="box">
			<div class="pane p_xl3">
				<section class="box mb_xl3">
					<h1 class="mb_0">work in progress</h1>
				</section>
				<section class="box pb_xl3">
					<footer>
						<a class="row p_md" href="{base}/about">
							<span class="font_size_lg mr_md">about</span>
							<Svg data={zzz_logo} size="var(--icon_size_md)" />
						</a>
					</footer>
				</section>
			</div>
		</div>
	</Dialog>
{/if}
