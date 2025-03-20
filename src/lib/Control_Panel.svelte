<script lang="ts">
	import Ping_Form from '$lib/Ping_Form.svelte';
	import Socket_Controls from '$lib/Socket_Controls.svelte';
	import Zzz_Dir_View from '$lib/Zzz_Dir_View.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {GLYPH_SERVER} from '$lib/glyphs.js';
	import Capability_Ollama from '$lib/Capability_Ollama.svelte';

	// interface Props {}

	// const {}: Props = $props();

	// TODO BLOCK http ping call to query server capability, a hardcoded endpoint for now
</script>

<div class="width_md">
	<section>
		<h2>
			<Glyph_Icon icon={GLYPH_SERVER} />
			server
		</h2>
		<section>
			<Zzz_Dir_View />
		</section>
		<section class="row gap_lg flex_wrap">
			<Ping_Form />
		</section>
		<section>
			<Socket_Controls />
		</section>
		<section>
			<Capability_Ollama />
		</section>
	</section>
</div>
