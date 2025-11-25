<script lang="ts">
	import Dialog from '@ryanatkn/fuz/Dialog.svelte';
	import {onNavigate} from '$app/navigation';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {resolve} from '$app/paths';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import {frontend_context} from '$lib/frontend.svelte.js';

	const {
		disabled,
	}: {
		disabled?: boolean | undefined;
	} = $props();

	const app = frontend_context.get();

	onNavigate(() => {
		if (app.ui.show_main_dialog) app.api.toggle_main_menu({show: false});
	});
</script>

{#if !disabled && app.ui.show_main_dialog}
	<Dialog onclose={() => app.api.toggle_main_menu({show: false})} layout="page">
		<div class="box">
			<div class="pane p_xl3">
				<section class="box mb_xl3">
					<h1 class="mb_0">work in progress</h1>
				</section>
				<section class="box pb_xl3">
					<footer>
						<a class="row p_md" href={resolve('/about')}>
							<span class="font_size_lg mr_md">about</span>
							<Svg data={zzz_logo} size="var(--icon_size_md)" />
						</a>
					</footer>
				</section>
			</div>
		</div>
	</Dialog>
{/if}
