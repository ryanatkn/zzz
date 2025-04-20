<script lang="ts">
	import {base} from '$app/paths';

	import {GLYPH_PROJECT} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Project_List from '$routes/projects/Project_List.svelte';
	import Project_Sidebar from '$routes/projects/Project_Sidebar.svelte';
	import {projects_context} from '$routes/projects/projects.svelte.js';

	const projects = projects_context.get();
</script>

{#if projects.previewing}
	<div class="flex">
		<Project_Sidebar />
		<main class="flex_1 p_md overflow_auto">
			{@render content()}
			<Project_List />
		</main>
	</div>
{:else}
	<div class="p_lg">
		{@render content()}
	</div>
{/if}

{#snippet content()}
	<h1><Glyph glyph={GLYPH_PROJECT} /> projects</h1>

	<section class="width_md">
		<p>
			When it's ready, Zzz will let you both <a href="{base}/tabs">browse websites</a> and also create
			them, so Zzz is both a browser and editor for the read-write web, and it can be used as a desktop
			app to deploy and manage sites, content, and other data and systems.
		</p>
		<p>
			Zzz tries to give us the maximum of the web's capabilities on all of our devices with minimal
			dependencies and optional third parties. A primary goal is to make managing websites routine
			and easy, because owning your web presence should be a cinch.
		</p>
		<p>
			Zzz doesn't try to be everything to everybody. That's what open standardized protocols are
			for! The goal here is to provide a streamlined extensible UX with one take on the web, with
			CMS and IDE features that leverage the rest of Zzz. Because it's the web, anything you make in
			Zzz can be used by other browsers and tools, and vice versa, like magic.
		</p>
		<p>
			Here's a very rough sketch of <button
				type="button"
				class="inline compact color_g"
				onclick={() => {
					projects.previewing = !projects.previewing;
				}}>what projects could look like</button
			>.
		</p>
		<p>
			For developers, Zzz is also an npm library for TypeScript, Svelte, SvelteKit, and Vite that
			can be used to make websites and servers with your current workflows.
		</p>
		<p>More <a href="{base}/about">about</a> Zzz.</p>
	</section>
{/snippet}
