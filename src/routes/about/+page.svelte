<script lang="ts">
	import Library_Footer from '@ryanatkn/fuz/Library_Footer.svelte';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import Package_Detail from '@ryanatkn/fuz/Package_Detail.svelte';
	import Community_Links_Panel from '@ryanatkn/fuz/Community_Links_Panel.svelte';
	import Breadcrumb from '@ryanatkn/fuz/Breadcrumb.svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';

	import {pkg_context} from '$routes/pkg.js';

	const pkg = pkg_context.get();

	// TODO standardize
</script>

<div class="width_md p_lg">
	<section>
		<header style:--size="var(--size_xl)">
			<h1 class="row">
				<Svg
					data={zzz_logo}
					fill="var(--text_color)"
					size="var(--icon_size_sm)"
					classes="ml_xs mr_xl"
				/> about
			</h1>
		</header>
		<p>
			Zzz, pronounced "zees" like the sound of electricity, is a bot and web toolkit. It's one
			example of what I call an "endgame web UI", a digital tool that adapts to your needs on the
			fly, while remaining fully in your control and always open.
		</p>
		<p>The main ideas include:</p>
		<ul>
			<li>open source</li>
			<li>fully controlled by the user</li>
			<li>optimize for UX first</li>
			<li>client is the nexus of many services</li>
			<li>local-first, pluggable cloud</li>
			<li>designed for extensibility</li>
			<li>customizable and programmable</li>
			<li>leverages the web dev ecosystem for TypeScript and Svelte</li>
			<li>encourages normal dev patterns, unintrusive to your preferred workflows</li>
			<li>
				progressively enhanced with capabilities like a local or remote web server and local model
				providers like Ollama
			</li>
		</ul>
		<p>
			I think there will be many tools like this in the future. Perhaps every person will use at
			least one, whether they know it or not? Or maybe it's just a weird web app. In any case, it's
			one developer's take on a web UI that hopes to evolve forwards with the ecosystem.
		</p>
		<p class="mt_xl5">
			⚠️ This is an early pre-release, see the <a href="https://github.com/ryanatkn/zzz"
				>readme and source code</a
			>
			and <a href="https://github.com/ryanatkn/zzz/discussions">discussions</a>.
		</p>
	</section>
	<section>
		<div class="panel p_md width_md">
			<Package_Detail {pkg} />
		</div>
	</section>
	<Community_Links_Panel />
	<section class="mb_xl7">
		<Library_Footer {pkg}>
			<div class="mb_xl5">
				<Breadcrumb><Svg data={zzz_logo} size="var(--icon_size_sm)" /></Breadcrumb>
			</div>
		</Library_Footer>
	</section>
</div>
