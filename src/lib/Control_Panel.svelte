<script lang="ts">
	import Ping_Form from '$lib/Ping_Form.svelte';
	import Socket_Controls from '$lib/Socket_Controls.svelte';

	// interface Props {}

	// const {}: Props = $props();

	// TODO
</script>

<div class="width_md">
	<section>
		<h2>server</h2>
		<section class="row gap_lg flex_wrap">
			<Ping_Form />
		</section>
		<section>
			<Socket_Controls />
		</section>
	</section>
</div>
