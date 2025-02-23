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
			Zzz, pronounced "zees" like the sound of electricity, is a bot and web toolkit with a focus on
			AI and user power. It's a digital tool that adapts to your needs on the fly, while remaining
			fully in your control and open source.
		</p>
		<p>The main ideas include:</p>
		<ul>
			<li>optimize for user agency and power</li>
			<li>care about UX for both power users and novices</li>
			<li>open source, permissive license, noncommercial project</li>
			<li>
				local-first architecture with user-owned data, offline functionality, and optional cloud
				sync
			</li>
			<li>
				interoperable design using standard and popular protocols, open APIs, and common data
				formats
			</li>
			<li>
				designed for plugins, scripting, and deep extensibility, and has a dev library in TypeScript
				and Svelte
			</li>
			<li>
				building blocks that you can configure and combine to create new experiences and tools that
				solve your unique problems, and share them with others
			</li>
			<li>
				adaptable interfaces that evolve with user needs through customization, context awareness,
				and AI assistance
			</li>
		</ul>
		<p>Integrations: (everything's a work in progress, but some basics work)</p>
		<ul>
			<li><a href="https://github.com/ollama/ollama">Ollama</a></li>
			<li><a href="https://github.com/openai/openai-node">ChatGPT</a></li>
			<li><a href="https://github.com/anthropics/anthropic-sdk-typescript">Claude</a></li>
			<li><a href="https://github.com/google-gemini/generative-ai-js">Gemini</a></li>
			<li>
				Planned:
				<ul>
					<li>RSS/Atom/JSONFeed</li>
					<li>
						<a href="https://modelcontextprotocol.io/">Model Context Protocol</a> (<a
							href="https://github.com/modelcontextprotocol/typescript-sdk">TS lib</a
						>)
					</li>
					<li>more planned, also I welcome feedback/requests/assistance</li>
				</ul>
			</li>
		</ul>
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
