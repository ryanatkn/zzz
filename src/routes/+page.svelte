<script lang="ts">
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {github_logo, zzz_logo} from '@ryanatkn/fuz/logos.js';
</script>

<main class="width_sm">
	<section class="box">
		<header class="box">
			<Svg data={zzz_logo} size="var(--icon_size_xl2)" classes="my_xl5" />
			<blockquote class="shadow_inset_xs bg px_xl">
				social toolz for the tired <a href="https://github.com/ryanatkn/zzz" title="View source"
					>💤</a
				>
			</blockquote>
		</header>
	</section>
	<section class="panel p_xl shadow_inset_sm">
		<div class="panel bg p_md shadow_sm">
			<p>
				Zzz (pronounced "zees" like please) is a social web app framework that builds on <a
					href="https://kit.svelte.dev/">SvelteKit</a
				>
				and several of <a href="https://www.ryanatkn.com/">my projects</a>. It's not yet published
				but should be in late 2024 or 2025, and I plan to make videos and blog posts about it here
				soon.
			</p>
			<p>on YouTube:</p>
			<ul>
				<li>
					<a href="https://www.youtube.com/@spiderspace_8000">@spiderspace_8000</a> -
					<a href="https://www.spiderspace.org/">spiderspace.org</a> - nontechnical design videos where
					we'll make a social website together with Zzz when it's ready
				</li>
				<li>
					<a href="https://www.youtube.com/@webdevladder">@webdevladder</a> -
					<a href="https://www.webdevladder.net/">webdevladder.net</a> - realworld webdev with TypeScript
					and Svelte
				</li>
				<li>
					<a href="https://www.youtube.com/@webdevladder_vods">@webdevladder_vods</a> - unedited videos
					of me programming
				</li>
			</ul>
			<p>
				See how Zzz fits with my other software on <a href="https://www.ryanatkn.com/"
					>my homepage</a
				>. To support the project visit
				<a href="https://www.ryanatkn.com/funding">ryanatkn.com/funding</a>.
			</p>
		</div>
	</section>
	<div class="shadow_inset_bottom_xs p_xl radius_lg mb_xl8 box">
		<footer class="box">
			<a
				class="box text_align_center px_xl py_md panel shadow_inset_bottom_xs"
				style:display="flex"
				href="https://github.com/ryanatkn/zzz"
				title="View source"
			>
				<div class="mb_xs">source code</div>
				<Svg data={github_logo} size="var(--icon_size_lg)" />
			</a>
		</footer>
	</div>
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
	/* TODO something like this but toned down
	a:hover {
		box-shadow: var(--shadow_md) color-mix(in hsl, var(--shadow_color) var(--shadow_alpha_3), transparent); 
	} */
	a:active {
		box-shadow: var(--shadow_inset_top_sm)
			color-mix(in hsl, var(--shadow_color) var(--shadow_alpha_2), transparent);
	}
</style>
