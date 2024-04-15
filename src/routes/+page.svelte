<script lang="ts">
	import Github_Logo from '@ryanatkn/fuz/Github_Logo.svelte';
</script>

<main class="width_sm">
	<section class="box">
		<header class="box">
			<h1><a href="https://github.com/ryanatkn/zzz">💤</a></h1>
			<blockquote class="shadow_inset_inverse_md">toolz for the tired</blockquote>
		</header>
	</section>
	<section class="panel p_lg shadow_inset_inverse_md">
		<div class="panel bg p_md shadow_md">
			<p>
				Zzz (pronounced "zees") is a social web app framework that builds on <a
					href="https://kit.svelte.dev/">SvelteKit</a
				>
				and several of <a href="https://www.ryanatkn.com/">my projects</a>. It's not yet published
				but should be in 2024 and I plan to write more about it here soon and make videos too.
			</p>
			<p>Subscribe on YouTube:</p>
			<ul>
				<li>
					<a href="https://www.youtube.com/@spiderspace_8000">@spiderspace_8000</a> - non-technical process
					and design videos
				</li>
				<li>
					<a href="https://www.youtube.com/@webdevladder">@webdevladder</a> - advanced technical videos
				</li>
			</ul>
			<p>
				The websites
				<a href="https://www.spiderspace.org/">spiderspace.org</a>
				and <a href="https://www.webdevladder.net/">webdevladder.net</a> will be created in future screencasts
				along with their Atom blog feeds.
			</p>
			<footer class="box">
				<a
					class="box text_align_center p_sm panel shadow_inset_md"
					style:display="flex"
					href="https://github.com/ryanatkn/zzz"
					><div class="mb_xs">source code</div>
					<Github_Logo /></a
				>
			</footer>
		</div>
	</section>
</main>

<style>
	main {
		display: flex;
		flex-direction: column;
		align-items: center;
		margin: 0 auto;
	}
	/* TODO accidentally selected all the links like this, I kind of like it */
	/* TODO construct for this in CSS classes */
	a:active {
		box-shadow: var(--shadow_inset_inverse_md);
	}
</style>
