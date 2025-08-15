<script lang="ts">
	import {blur, fly, slide} from 'svelte/transition';
	import {base} from '$app/paths';

	import {DURATION_LG} from '$lib/helpers.js';
	import {frontend_context} from '$lib/frontend.svelte.js';

	const app = frontend_context.get();
</script>

{#if app.ui.tutorial_for_prompts}
	<div class="pt_lg" out:slide={{delay: DURATION_LG}}>
		<div out:blur={{duration: DURATION_LG}}>
			<aside out:fly={{duration: DURATION_LG, y: -1, x: 10}}>
				<p>
					The plan here is to experiment with many ideas for making and managing prompts, both
					simpler and more complex than this first iteration. We'll likewise explore variants of the <a
						href="{base}/chat">chat</a
					> interface.
				</p>
				<p>
					As the system vocabulary and APIs are refined, it should get easier for novices to make
					their ideas with TypeScript and Svelte. Share your ideas in the <a
						href="https://github.com/ryanatkn/zzz/discussions">discussions</a
					>.
				</p>
				<button
					type="button"
					class="compact"
					onclick={() => {
						app.ui.tutorial_for_prompts = false;
					}}>okay</button
				>
			</aside>
		</div>
	</div>
{/if}
