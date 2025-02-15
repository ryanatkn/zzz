<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import {base} from '$app/paths';

	import File_List from '$lib/File_List.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	const files = $derived(Array.from(zzz.files_by_id.values()).filter((file) => !file.external));
</script>

<header class="box">
	<a href="{base}/"><Svg data={zzz_logo} size="var(--icon_size_xl2)" classes="my_xl5" /></a>
	<h1>Files</h1>
</header>

<section>
	<File_List {files} />
</section>
