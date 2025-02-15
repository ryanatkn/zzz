<script lang="ts">
	import File_List from '$lib/File_List.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const zzz = zzz_context.get();

	const files = $derived(Array.from(zzz.files_by_id.values()).filter((file) => !file.external));
</script>

<section>
	<File_List {files} />
</section>
