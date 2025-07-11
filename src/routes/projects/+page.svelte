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
	<div class="display_flex">
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
			them. Websites are just one kind of thing that you can make in a project, a project could be a
			simple collection of documents, with a UX no more complex than a folder. This makes Zzz both a
			browser and an editor for the read-write web, and it can be used as a desktop app to deploy and
			manage sites, content, and other data and systems.
		</p>
		<p>
			Zzz tries to give us the maximum of the web's capabilities on all of our devices with minimal
			dependencies and optional third parties. A primary goal is to make managing websites routine
			and easy, because owning your web presence should be a cinch.
		</p>
		<p>
			The goal of this "projects" design sketch is to provide a streamlined extensible UX with one
			take on building for the web, with integrated CMS and IDE features. This abstraction makes
			rough sense for my workflows. A project can have many repos, and other things like files and
			user data, and a repo can be referenced by many projects.
		</p>
		<p>
			Try as it might to be flexible, Zzz can't be everything to everybody. But we have open
			standardized protocols! Because it's the web, anything you make in Zzz can be used by other
			browsers and tools, and vice versa, like magic.
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
			For developers, Zzz is also an npm library for TypeScript/Svelte/SvelteKit/Vite that can be
			used to make websites and servers with your current workflows.
		</p>
		<p>More <a href="{base}/about">about</a> Zzz.</p>
	</section>
{/snippet}
