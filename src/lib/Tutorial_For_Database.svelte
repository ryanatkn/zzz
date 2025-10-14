<script lang="ts">
	import {blur, scale, slide} from 'svelte/transition';
	import {sineInOut} from 'svelte/easing';

	import External_Link from '$lib/External_Link.svelte';
	import {DURATION_LG} from '$lib/helpers.js';
	import {frontend_context} from '$lib/frontend.svelte.js';

	const app = frontend_context.get();
</script>

{#if app.ui.tutorial_for_database}
	<div class="pt_lg" out:slide={{delay: DURATION_LG}}>
		<div out:blur={{duration: DURATION_LG}}>
			<aside out:scale={{duration: DURATION_LG, easing: (t) => sineInOut(t / 3)}}>
				<p>
					⚠️ This is an early prototype and your prompts are not saved yet, they are gone when you
					refresh the page. Soon the Node backend will persist data to a Postgres or pglite
					database. (<External_Link href="https://github.com/ryanatkn/zzz/issues/7"
						>issue 7</External_Link
					>)
				</p>
				<button
					type="button"
					class="compact"
					onclick={() => {
						app.ui.tutorial_for_database = false;
					}}>ok</button
				>
			</aside>
		</div>
	</div>
{/if}
