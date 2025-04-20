<script lang="ts">
	import {base} from '$app/paths';

	import {projects_context} from '$routes/projects/projects.svelte.js';
	import Project_Sidebar from '$routes/projects/Project_Sidebar.svelte';
	import Section_Sidebar from '$routes/projects/Section_Sidebar.svelte';
	import Pages_Sidebar from '$routes/projects/Pages_Sidebar.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_ADD} from '$lib/glyphs.js';

	const projects = projects_context.get();

	const project_viewmodel = $derived(projects.current_project_viewmodel);

	const page_count = $derived(project_viewmodel?.project?.pages.length);
</script>

<div class="project_layout">
	<Project_Sidebar />
	<Section_Sidebar section="pages" />
	<Pages_Sidebar />

	<div class="project_content">
		{#if project_viewmodel?.project}
			<div class="p_lg">
				<h1 class="mb_lg">Pages</h1>

				{#if !page_count}
					<p>This project doesn't have any web pages yet.</p>
					<p>
						<button
							type="button"
							class="color_a"
							onclick={() => project_viewmodel.create_new_page()}
						>
							<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> create your first page
						</button>
					</p>
				{:else}
					<table class="w_100">
						<thead>
							<tr>
								<th>title</th>
								<th>path</th>
								<th>created</th>
								<th>updated</th>
							</tr>
						</thead>
						<tbody>
							{#each project_viewmodel.project.pages as page (page.id)}
								<tr>
									<td>
										<a href="{base}/projects/{project_viewmodel.project_id}/pages/{page.id}"
											>{page.title}</a
										>
									</td>
									<td>{page.path}</td>
									<td>{new Date(page.created).toLocaleString()}</td>
									<td>{new Date(page.updated).toLocaleString()}</td>
								</tr>
							{/each}
						</tbody>
					</table>

					<div class="mb_lg">
						<button
							type="button"
							class="color_a"
							onclick={() => project_viewmodel.create_new_page()}
						>
							<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> new page
						</button>
					</div>
				{/if}
			</div>
		{:else}
			<div class="p_lg text_align_center">
				<p>Project not found.</p>
			</div>
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
