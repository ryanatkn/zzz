<script lang="ts">
	import Github_Logo from '@ryanatkn/fuz/Github_Logo.svelte';
</script>

<main class="width_sm">
	<section class="box">
		<header class="box">
			<h1><a href="https://github.com/ryanatkn/zzz" title="View source">💤</a></h1>
			<blockquote class="shadow_inset_inverse_md px_xl">toolz for the tired</blockquote>
		</header>
	</section>
	<section class="panel p_lg shadow_inset_inverse_md">
		<div class="panel bg p_md shadow_md">
			<p>
				Zzz (pronounced "zees") is a social web app framework that builds on <a
					href="https://kit.svelte.dev/">SvelteKit</a
				>
				and several of <a href="https://www.ryanatkn.com/">my projects</a>. It's not yet published
				but should be in 2024 and I plan to make videos and blog about it here soon.
			</p>
			<p>Subscribe on YouTube:</p>
			<ul>
				<li>
					<a href="https://www.youtube.com/@spiderspace_8000">@spiderspace_8000</a> - nontechnical process
					and design videos
				</li>
				<li>
					<a href="https://www.youtube.com/@webdevladder">@webdevladder</a> - advanced programming videos
				</li>
			</ul>
			<p>
				The websites
				<a href="https://www.spiderspace.org/">spiderspace.org</a>
				and <a href="https://www.webdevladder.net/">webdevladder.net</a> will be created in future screencasts
				along with their Atom blog feeds.
			</p>
		</div>
	</section>
	<footer class="box mb_xl7">
		<a
			class="box text_align_center p_sm panel shadow_inset_md"
			style:display="flex"
			href="https://github.com/ryanatkn/zzz"
			title="View source"
		>
			<div class="mb_xs">source code</div>
			<Github_Logo />
		</a>
	</footer>
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
