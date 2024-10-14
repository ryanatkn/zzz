<script lang="ts">
	import {zzz_context} from '$lib/zzz.svelte.js';
	import File_List from '$lib/File_List.svelte';
	import Multiprompt from './Multiprompt.svelte';

	interface Props {}

	const {}: Props = $props();

	const zzz = zzz_context.get();

	const hello_server = () => {
		zzz.client.send({type: 'echo', data: 'hello server'});
	};

	// TODO
</script>

<section class="box width_100 mx_auto p_md panel">
	<section>
		<button type="button" onclick={hello_server}>⛬ hello server</button>
	</section>

	<Multiprompt />
</section>
<section>
	<File_List files={zzz.files_by_id} />
</section>
