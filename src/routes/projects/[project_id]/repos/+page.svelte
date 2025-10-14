<script lang="ts">
	// @slop Claude Opus 4

	import {projects_context} from '$routes/projects/projects.svelte.js';
	import Project_Sidebar from '$routes/projects/Project_Sidebar.svelte';
	import Section_Sidebar from '$routes/projects/Section_Sidebar.svelte';
	import Repos_Sidebar from '$routes/projects/Repos_Sidebar.svelte';
	import {GLYPH_ADD} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Repo_Table_Row from '$routes/projects/Repo_Table_Row.svelte';
	import Project_Not_Found from '$routes/projects/Project_Not_Found.svelte';

	const projects = projects_context.get();

	const project_viewmodel = $derived(projects.current_project_viewmodel);
	const project = $derived(projects.current_project);
</script>

<div class="project_layout">
	<!-- TODO @many refactor for better component instance stability for e.g. transitions -->
	<Project_Sidebar />
	{#if project}
		<Section_Sidebar {project} section="repos" />
		<Repos_Sidebar />
	{/if}

	<div class="project_content">
		{#if project_viewmodel?.project}
			<div class="p_lg">
				<h1 class="mb_lg">repos</h1>

				{#if project_viewmodel.project.repos.length === 0}
					<div class="panel p_lg text_align_center mb_lg">
						<p>this project has no repositories configured yet</p>
						<p>
							<button
								type="button"
								class="color_a"
								onclick={() => project_viewmodel.create_new_repo()}
							>
								<Glyph glyph={GLYPH_ADD} />&nbsp; add your first repo
							</button>
						</p>
					</div>
				{:else}
					<table class="width_100">
						<thead>
							<tr>
								<th>repo</th>
								<th>checkouts</th>
								<th>created</th>
								<th>updated</th>
							</tr>
						</thead>
						<tbody>
							{#each project_viewmodel.project.repos as repo (repo.id)}
								<Repo_Table_Row {repo} project_id={project_viewmodel.project_id} />
							{/each}
						</tbody>
					</table>
				{/if}

				<div>
					<button type="button" class="color_a" onclick={() => project_viewmodel.create_new_repo()}>
						<Glyph glyph={GLYPH_ADD} />&nbsp; new repo
					</button>
				</div>
			</div>
		{:else}
			<Project_Not_Found />
		{/if}
	</div>
</div>

<style>
	.project_layout {
		display: flex;
		height: 100%;
		overflow: hidden;
	}

	.project_content {
		flex: 1;
		overflow: auto;
	}
</style>
